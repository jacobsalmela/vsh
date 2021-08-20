// vsh.v -- Runs v shell

/* This file is part of vsh, the V SHell.

	MIT License

	Copyright (C) 2021 Jacob Salmela <me@jacobsalmela.com>

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice (including the next paragraph) shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import os { input, execute, user_os, join_path home_dir }
import term.ui as tui

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
	return View{
		raw: raw
		cursor: Cursor{
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

fn cmd_execute(mut h os.File, mut buffer &Buffer, cmd string) {
	// write the command to the history file
	h.writeln(cmd) or { panic(err) }

	// run the command the user entered
	mut output := os.execute(cmd)

	// Display the output even if the command failed (so the user can see the failure)
	buffer.put('\n$output.output')
}

fn event(e &tui.Event, x voidptr) {
	mut vsh := &Vsh(x)
	mut buffer := vsh.cur

	// open the history file for appending commands to it
	mut hist_append := os.open_append(os.join_path(os.home_dir(), '.v_history')) or {
		vsh.cur.put('\nv# $err')
		return
	}
	defer { hist_append.close() }

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
				if cmd == '' {
					// if nothing was typed on the command line, return the prompt
					buffer.put('\n')
					buffer.put('v# ')
				} else {
					// run the command the user entered
					cmd_execute(mut hist_append, mut buffer, cmd)

					// return the prompt so another command can be entered
					buffer.put('v# ')
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
				// open the history file
				h_file := os.join_path(os.home_dir(), '.v_history').str()
				hist := os.read_file(h_file) or { panic(err) }

				// get the length of the current line
				mut amount := buffer.cur_line().len

				// iterator for looping through history file
				mut i := 0

				// length of the history array
				mut cnt := hist.len

				// var for the command to be displayed to the user
				mut cmd := ''

				// this is the length of the current prompt 'v# '
				if amount == 3 {
					// show the line of history
					// translated to v for this functionality: https://www.includehelp.com/c-programs/c-program-to-print-contents-in-reverse-order-of-a-file-like-tac-command-in-linux.aspx
					// loops through each character in the history file
					for l in hist.bytes().reverse() {
						// add the character to the command var
						cmd += l.ascii_str()
						// if we hit a newline, the command is complete, but backwards
						if l.ascii_str() == '\n' {
							// subtract from the length of the array
							cnt--
							// increment the loop
							i++
							// display the command in reverse (which shows it correctly)
							buffer.put('v# ${cmd.reverse()}')
							// clear the command var for the next command
							cmd = ''
						}
						break
					}
				} else {
					// delete the entire line
					buffer.del(-amount)
					// TODO: Make this into a function since it's the same as above
					for l in hist.bytes().reverse() {
						cmd += l.ascii_str()
						if l.ascii_str() == '\n' {
							cnt--
							i++
							buffer.put('v# ${cmd.reverse()}')
							cmd = ''
						}
					}
				}
			}
			.down {
				buffer.put('\nv# hist fwd')
			}
			// https://modules.vlang.io/term.ui.html#KeyCode
			48...57, 65...90, 97...122 {
				buffer.put(e.ascii.ascii_str()) // 0-9, A-Z, a-z
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
			// https://modules.vlang.io/term.ui.html#Modifiers
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
	// display the accumulated print buffer to the screen
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
	  // a pointer to any user_data, it will be passed as the last argument to each callback
		user_data: vsh
		// a callback that will be called after initialization and before the first event / frame
		init_fn: init
		// a callback that will be fired on each frame, at a rate of frame_rate frames per second. event_fn fn(&Event, voidptr) - a callback that will be fired for every event received
		frame_fn: frame
		event_fn: event
		// sets the title of the terminal window. This may be changed later, by calling the set_window_title() method
		window_title: 'vsh'
		// whether to hide the mouse cursor
		hide_cursor: false
		// sets the terminal into raw mode, which makes it intercept some escape codes such as ctrl + c and ctrl + z
		capture_events: true
		// the number of times per second that the frame callback will be fired. 30fps is a nice balance between smoothness and performance, but you can increase or lower it as you wish
		frame_rate: 30
		// a list of reset signals, to setup handlers to cleanup the terminal state when they're received. You should not need to change this, unless you know what you're doing.
		// reset: [1, 2, 3, 4, 6, 7, 8, 9, 11, 13, 14, 15, 19]
		// reset: []os.Signal{}
		use_alternate_buffer: true
	)

	// debug := true
	vsh.tui.run() ?
}
