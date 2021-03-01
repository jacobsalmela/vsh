// vsh.v -- Runs v shell

/* This file is part of vsh, the V SHell.

	MIT License

	Copyright (C) 2021 Jacob Salmela <me@jacobsalmela.com>

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice (including the next paragraph) shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import os { input, exec, user_os, join_path home_dir }
import term.ui as tui
import io
// import builtins

struct Vsh {
mut:
	tui           &tui.Context  = 0
	cur           &Buffer       = 0
	magnet_x      int
	viewport      int
}

struct View {
pub:
	raw    string
	cursor Cursor
}

struct Buffer {
pub mut:
	lines  []string
	cursor Cursor
}

struct Cursor {
pub mut:
	pos_x int
	pos_y int
}

enum Movement {
	left
	right
}

fn (mut c Cursor) set(x int, y int) {
	c.pos_x = x
	c.pos_y = y
}

fn (mut c Cursor) move(x int, y int) {
	c.pos_x += x
	c.pos_y += y
}

fn (c Cursor) xy() (int, int) {
	return c.pos_x, c.pos_y
}

// magnet_cursor_x will place the cursor as close to it's last move left or right as possible
fn (mut vsh Vsh) magnet_cursor_x() {
	mut buffer := vsh.cur
	if buffer.cursor.pos_x < vsh.magnet_x {
		if vsh.magnet_x < buffer.cur_line().len {
			move_x := vsh.magnet_x - buffer.cursor.pos_x
			buffer.move_cursor(move_x, .right)
		}
	}
}

// App callbacks
fn init(x voidptr) {
	mut vsh := &Vsh(x)
	vsh.init_shell()
}

fn (mut vsh Vsh) init_shell() {
	vsh.cur = &Buffer{}
	vsh.cur.put('Welcome to v shell!')
	vsh.cur.put('\nv# ')
}

fn (b Buffer) flat() string {
	return b.raw().replace_each(['\n', r'\n', '\t', r'\t'])
}

fn (b Buffer) raw() string {
	return b.lines.join('\n')
}

fn (b Buffer) view(from int, to int) View {
	l := b.cur_line()
	mut x := 0
	for i := 0; i < b.cursor.pos_x && i < l.len; i++ {
		x++
	}
	mut lines := []string{}
	for i, line in b.lines {
		if i >= from && i <= to {
			lines << line
		}
	}
	raw := lines.join('\n')
	return {
		raw: raw
		cursor: {
			pos_x: x
			// pos_y: b.cursor.pos_y
		}
	}
}

fn (b Buffer) line(i int) string {
	if i < 0 || i >= b.lines.len {
		return ''
	}
	return b.lines[i]
}

fn (b Buffer) cur_line() string {
	return b.line(b.cursor.pos_y)
}

fn (b Buffer) cursor_index() int {
	mut i := 0
	for y, line in b.lines {
		if b.cursor.pos_y == y {
			i += b.cursor.pos_x
			break
		}
		i += line.len + 1
	}
	return i
}

fn (mut b Buffer) put(s string) {
	// if the string contains a line ending
	has_line_ending := s.contains('\n')
	x, y := b.cursor.xy()
	if b.lines.len == 0 {
		b.lines.prepend('')
	}
	line := b.lines[y]
	l, r := line[..x], line[x..]
	if has_line_ending {
		mut lines := s.split('\n')
		lines[0] = l + lines[0]
		lines[lines.len - 1] += r
		b.lines.delete(y)
		b.lines.insert(y, lines)
		last := lines[lines.len - 1]
		b.cursor.set(last.len, y + lines.len - 1)
		if s == '\n' {
			b.cursor.set(0, b.cursor.pos_y)
		}
	} else {
		b.lines[y] = l + s + r
		b.cursor.set(x + s.len, y)
	}
	$if debug {
		flat := s.replace('\n', r'\n')
		eprintln(@MOD + '.' + @STRUCT + '::' + @FN + ' "$flat"')
	}
}

fn (mut b Buffer) del(amount int) string {
	x, y := b.cursor.xy()
	if amount < 0 { // don't delete left if we're at 0,0
		// if we're at the prompt's end, stop
		if x == 3 {
			return ''
		}
	}
	mut removed := ''
	if amount < 0 { // backspace (backward)
		i := b.cursor_index()
		removed = b.raw()[i + amount..i]
		mut left := amount * -1
		for li := y; li >= 0 && left > 0; li-- {
			ln := b.lines[li]
			if left > ln.len {
				b.lines.delete(li)
			} else {
				if ln.len == 0 {
					b.cursor.pos_x = 0
				} else if x == 1 {
					b.lines[li] = b.lines[li][left..]
					b.cursor.pos_x = 0
				} else {
					b.lines[li] = ln[..x - left] + ln[x..]
					b.cursor.pos_x -= left
				}
				left = 0
				break
			}
		}
	} else { // delete (forward)
		i := b.cursor_index() + 1
		removed = b.raw()[i - amount..i]
		mut left := amount
		for li := y; li >= 0 && left > 0; li++ {
			ln := b.lines[li]
			if x == ln.len { // at line end
					b.lines[li] = ln + b.lines[y + 1]
					b.lines.delete(y + 1)
					left--
					b.del(left)
			} else if left > ln.len {
				b.lines.delete(li)
				left -= ln.len
			} else {
				b.lines[li] = ln[..x] + ln[x + left..]
				left = 0
			}
			break
		}
	}
	return removed
}

// move_cursor will navigate the cursor within the buffer bounds
fn (mut b Buffer) move_cursor(amount int, movement Movement) {
	cur_line := b.cur_line()
	match movement {
		.left {
			if b.cursor.pos_x - amount >= 0 {
				b.cursor.move(-amount, 0)
			}
		}
		.right {
			if b.cursor.pos_x + amount <= cur_line.len {
				b.cursor.move(amount, 0)
			}
		}
	}
}

fn (vsh &Vsh) view_width() int {
	return vsh.tui.window_width
}

fn event(e &tui.Event, x voidptr) {
	mut vsh := &Vsh(x)
	mut buffer := vsh.cur
    
	mut hist_append := os.open_append(os.join_path(os.home_dir(), '.v_history')) or {
		vsh.cur.put('\nv# $err')
		return
	}
	mut hist_read := os.open(os.join_path(os.home_dir(), '.v_history')) or {
		vsh.cur.put('\nv# $err')
		return
	}    
	defer { hist_append.close() }
	defer { hist_read.close() }
    
	// vsh.tui.write('\nv# "$e.utf8.bytes().hex()" = $e.utf8.bytes()')
	vsh.tui.write('\nv# ')

	if e.typ == .key_down {
		// match the event code (keystroke)
		match e.code {
			.escape {
				exit(0)
			}
			.enter {
				// the command is anything that's not our prompt
				// TODO: use a var and don't hard code this, the prompt will be variable in length
				cmd := buffer.cur_line()[3..]

				// split with a delimeter of space and then grab the first entry to see if it should be a builtin command
				is_builtin := cmd.split(' ')[0]
				// get the rest of the string which will be the args
				cmd_args := cmd.split(' ')[1..]
				match is_builtin {
					// only use the first arg since you can't be in two dirs at once
					'cd' { os.chdir(cmd.split(' ')[1])
								 buffer.put('v# ') }
					'pwd' { buffer.put('\n$os.getwd()\n')
				 					buffer.put('v# ')}
				else {
					// run the command the user entered
					// TODO: move this all to a function and make it more resilient
					output := os.exec(cmd) or {
						buffer.put('\n$err')
						buffer.put('v# ')
						return
					}

					// write the command to the history file
					hist_append.writeln(cmd) or { panic(err) }

					// display it's output
					buffer.put('\n$output.output')

					// return the prompt so another command can be entered
					buffer.put('v# ')
					}
				}
			}
			.space {
				buffer.put(' ')
			}
			.backspace {
				buffer.del(-1)
			}
			.delete {
				buffer.del(1)
			}
			.left {
				buffer.move_cursor(1, .left)
			}
			.right {
				buffer.move_cursor(1, .right)
			}
			.up {
				mut history := io.new_buffered_reader(reader: io.make_reader(hist_read))
				buffer.put('\nv# $history')
				for {
					l := history.read_line() or {
						buffer.put('\nv# $err')
						buffer.put('v# ')
						return
					}
					buffer.put('\nv# $l')
				}
			}
			.down {
				buffer.put('\nv# hist fwd')
			}
			48...57, 65...90, 97...122 { // 0-9, A-Z, a-z
				// buffer.put(e.utf8.bytes().bytestr())
				buffer.put(e.ascii.ascii_str())
			}
			33...47, 58...64, 91...96, 123...126  { // special characters
																							// !"#$%a'-./
																							// :;<=>?@
																							// [\]^_`
																							// {\}~
				buffer.put(e.ascii.ascii_str())
			}
		else {
			buffer.put('\nv# ')
			buffer.put(e.ascii.ascii_str())
			// if e.modifiers != 0 {
			// 	vsh.tui.write('\nModifiers: $e.modifiers = ')
			// 	if e.modifiers & tui.ctrl != 0 {
			// 		vsh.tui.write('ctrl. ')
			// 	}
			// 	if e.modifiers & tui.shift != 0 {
			// 		vsh.tui.write('shift ')
			// 	}
			// 	if e.modifiers & tui.alt != 0 {
			// 		vsh.tui.write('alt. ')
			// 	}
			// }
				// buffer.put(e.utf8.bytes().bytestr())
			}
		}
	vsh.tui.flush()
	}
}

fn frame(x voidptr) {
	mut vsh := &Vsh(x)
	mut cur := vsh.cur
	vsh.tui.clear()
	scroll_limit := vsh.view_width()
	view := cur.view(vsh.viewport, scroll_limit + vsh.viewport)
	vsh.tui.draw_text(0, 0, view.raw)
	vsh.tui.set_cursor_position(view.cursor.pos_x + 1, cur.cursor.pos_y + 1 - vsh.viewport)
	vsh.tui.flush()
}

fn main() {
	mut vsh := &Vsh{}
	vsh.tui = tui.init(
		user_data: vsh
		event_fn: event
		init_fn: init
		frame_fn: frame
		window_title: 'vsh'
		hide_cursor: false
		capture_events: true
		frame_rate: 120
		use_alternate_buffer: false
	)

	println('Welcome to v shell\n')
	// debug := true
	vsh.tui.run() ?
}
