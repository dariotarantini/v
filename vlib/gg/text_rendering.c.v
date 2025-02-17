// Copyright (c) 2019-2022 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license that can be found in the LICENSE file.
module gg

import fontstash
import sokol.sfons
import sokol.sgl
import gx
import os

struct FT {
pub:
	fons        &fontstash.Context
	font_normal int
	font_bold   int
	font_mono   int
	font_italic int
	scale       f32 = 1.0
}

fn new_ft(c FTConfig) ?&FT {
	if c.font_path == '' {
		if c.bytes_normal.len > 0 {
			fons := sfons.create(512, 512, 1)
			bytes_normal := c.bytes_normal
			bytes_bold := if c.bytes_bold.len > 0 {
				c.bytes_bold
			} else {
				debug_font_println('setting bold variant to normal')
				bytes_normal
			}
			bytes_mono := if c.bytes_mono.len > 0 {
				c.bytes_mono
			} else {
				debug_font_println('setting mono variant to normal')
				bytes_normal
			}
			bytes_italic := if c.bytes_italic.len > 0 {
				c.bytes_italic
			} else {
				debug_font_println('setting italic variant to normal')
				bytes_normal
			}

			return &FT{
				fons: fons
				font_normal: fons.add_font_mem('sans', bytes_normal, false)
				font_bold: fons.add_font_mem('sans', bytes_bold, false)
				font_mono: fons.add_font_mem('sans', bytes_mono, false)
				font_italic: fons.add_font_mem('sans', bytes_italic, false)
				scale: c.scale
			}
		} else {
			// Load default font
		}
	}

	if c.font_path == '' || !os.exists(c.font_path) {
		$if !android {
			println('failed to load font "$c.font_path"')
			return none
		}
	}

	mut normal_path := c.font_path
	mut bytes := []byte{}
	$if android {
		// First try any filesystem paths
		bytes = os.read_bytes(c.font_path) or { []byte{} }
		if bytes.len == 0 {
			// ... then try the APK asset path
			bytes = os.read_apk_asset(c.font_path) or {
				println('failed to load font "$c.font_path"')
				return none
			}
		}
	} $else {
		bytes = os.read_bytes(c.font_path) or {
			println('failed to load font "$c.font_path"')
			return none
		}
	}
	mut bold_path := if c.custom_bold_font_path != '' {
		c.custom_bold_font_path
	} else {
		get_font_path_variant(c.font_path, .bold)
	}
	bytes_bold := os.read_bytes(bold_path) or {
		debug_font_println('failed to load font "$bold_path"')
		bold_path = c.font_path
		bytes
	}
	mut mono_path := get_font_path_variant(c.font_path, .mono)
	bytes_mono := os.read_bytes(mono_path) or {
		debug_font_println('failed to load font "$mono_path"')
		mono_path = c.font_path
		bytes
	}
	mut italic_path := get_font_path_variant(c.font_path, .italic)
	bytes_italic := os.read_bytes(italic_path) or {
		debug_font_println('failed to load font "$italic_path"')
		italic_path = c.font_path
		bytes
	}
	fons := sfons.create(512, 512, 1)
	debug_font_println('Font used for font_normal : $normal_path')
	debug_font_println('Font used for font_bold   : $bold_path')
	debug_font_println('Font used for font_mono   : $mono_path')
	debug_font_println('Font used for font_italic : $italic_path')
	return &FT{
		fons: fons
		font_normal: fons.add_font_mem('sans', bytes, false)
		font_bold: fons.add_font_mem('sans', bytes_bold, false)
		font_mono: fons.add_font_mem('sans', bytes_mono, false)
		font_italic: fons.add_font_mem('sans', bytes_italic, false)
		scale: c.scale
	}
}

pub fn (ctx &Context) set_cfg(cfg gx.TextCfg) {
	if !ctx.font_inited {
		return
	}
	if cfg.bold {
		ctx.ft.fons.set_font(ctx.ft.font_bold)
	} else if cfg.mono {
		ctx.ft.fons.set_font(ctx.ft.font_mono)
	} else if cfg.italic {
		ctx.ft.fons.set_font(ctx.ft.font_italic)
	} else {
		ctx.ft.fons.set_font(ctx.ft.font_normal)
	}
	scale := if ctx.ft.scale == 0 { f32(1) } else { ctx.ft.scale }
	size := if cfg.mono { cfg.size - 2 } else { cfg.size }
	ctx.ft.fons.set_size(scale * f32(size))
	ctx.ft.fons.set_align(int(cfg.align) | int(cfg.vertical_align))
	color := sfons.rgba(cfg.color.r, cfg.color.g, cfg.color.b, cfg.color.a)
	if cfg.color.a != 255 {
		sgl.load_pipeline(ctx.timage_pip)
	}
	ctx.ft.fons.set_color(color)
	ascender := f32(0.0)
	descender := f32(0.0)
	lh := f32(0.0)
	ctx.ft.fons.vert_metrics(&ascender, &descender, &lh)
}

pub fn (ctx &Context) draw_text(x int, y int, text_ string, cfg gx.TextCfg) {
	$if macos {
		if ctx.native_rendering {
			if cfg.align == gx.align_right {
				width := ctx.text_width(text_)
				C.darwin_draw_string(x - width, ctx.height - y, text_, cfg)
			} else {
				C.darwin_draw_string(x, ctx.height - y, text_, cfg)
			}
			return
		}
	}
	if !ctx.font_inited {
		eprintln('gg: draw_text(): font not initialized')
		return
	}
	// text := text_.trim_space() // TODO remove/optimize
	// mut text := text_
	// if text.contains('\t') {
	// text = text.replace('\t', '    ')
	// }
	ctx.set_cfg(cfg)
	scale := if ctx.ft.scale == 0 { f32(1) } else { ctx.ft.scale }
	ctx.ft.fons.draw_text(x * scale, y * scale, text_) // TODO: check offsets/alignment
}

pub fn (ctx &Context) draw_text_def(x int, y int, text string) {
	ctx.draw_text(x, y, text)
}

/*
pub fn (mut gg FT) init_font() {
}
*/
pub fn (ft &FT) flush() {
	sfons.flush(ft.fons)
}

pub fn (ctx &Context) text_width(s string) int {
	$if macos {
		if ctx.native_rendering {
			return C.darwin_text_width(s)
		}
	}
	// ctx.set_cfg(cfg) TODO
	if !ctx.font_inited {
		return 0
	}
	mut buf := [4]f32{}
	ctx.ft.fons.text_bounds(0, 0, s, &buf[0])
	if s.ends_with(' ') {
		return int((buf[2] - buf[0]) / ctx.scale) +
			ctx.text_width('i') // TODO fix this in fontstash?
	}
	res := int((buf[2] - buf[0]) / ctx.scale)
	// println('TW "$s" = $res')
	$if macos {
		if ctx.native_rendering {
			return res * 2
		}
	}
	return int((buf[2] - buf[0]) / ctx.scale)
}

pub fn (ctx &Context) text_height(s string) int {
	// ctx.set_cfg(cfg) TODO
	if !ctx.font_inited {
		return 0
	}
	mut buf := [4]f32{}
	ctx.ft.fons.text_bounds(0, 0, s, &buf[0])
	return int((buf[3] - buf[1]) / ctx.scale)
}

pub fn (ctx &Context) text_size(s string) (int, int) {
	// ctx.set_cfg(cfg) TODO
	if !ctx.font_inited {
		return 0, 0
	}
	mut buf := [4]f32{}
	ctx.ft.fons.text_bounds(0, 0, s, &buf[0])
	return int((buf[2] - buf[0]) / ctx.scale), int((buf[3] - buf[1]) / ctx.scale)
}

pub fn system_font_path() string {
	env_font := os.getenv('VUI_FONT')
	if env_font != '' && os.exists(env_font) {
		return env_font
	}
	$if windows {
		debug_font_println('Using font "C:\\Windows\\Fonts\\arial.ttf"')
		return 'C:\\Windows\\Fonts\\arial.ttf'
	}
	$if macos {
		fonts := ['/System/Library/Fonts/SFNS.ttf', '/System/Library/Fonts/SFNSText.ttf',
			'/Library/Fonts/Arial.ttf']
		for font in fonts {
			if os.is_file(font) {
				debug_font_println('Using font "$font"')
				return font
			}
		}
	}
	$if android {
		xml_files := ['/system/etc/system_fonts.xml', '/system/etc/fonts.xml',
			'/etc/system_fonts.xml', '/etc/fonts.xml', '/data/fonts/fonts.xml',
			'/etc/fallback_fonts.xml']
		font_locations := ['/system/fonts', '/data/fonts']
		for xml_file in xml_files {
			if os.is_file(xml_file) && os.is_readable(xml_file) {
				xml := os.read_file(xml_file) or { continue }
				lines := xml.split('\n')
				mut candidate_font := ''
				for line in lines {
					if line.contains('<font') {
						candidate_font = line.all_after('>').all_before('<').trim(' \n\t\r')
						if candidate_font.contains('.ttf') {
							for location in font_locations {
								candidate_path := os.join_path(location, candidate_font)
								if os.is_file(candidate_path) && os.is_readable(candidate_path) {
									debug_font_println('Using font "$candidate_path"')
									return candidate_path
								}
							}
						}
					}
				}
			}
		}
	}
	mut fm := os.execute("fc-match --format='%{file}\n' -s")
	if fm.exit_code == 0 {
		lines := fm.output.split('\n')
		for l in lines {
			if !l.contains('.ttc') {
				debug_font_println('Using font "$l"')
				return l
			}
		}
	} else {
		panic('fc-match failed to fetch system font')
	}
	panic('failed to init the font')
}

fn get_font_path_variant(font_path string, variant FontVariant) string {
	// TODO: find some way to make this shorter and more eye-pleasant
	// NotoSans, LiberationSans, DejaVuSans, Arial and SFNS should work
	mut file := os.file_name(font_path)
	mut fpath := font_path.replace(file, '')
	file = file.replace('.ttf', '')

	match variant {
		.normal {}
		.bold {
			if fpath.ends_with('-Regular') {
				file = file.replace('-Regular', '-Bold')
			} else if file.starts_with('DejaVuSans') {
				file += '-Bold'
			} else if file.to_lower().starts_with('arial') {
				file += 'bd'
			} else {
				file += '-bold'
			}
			$if macos {
				if os.exists('SFNS-bold') {
					file = 'SFNS-bold'
				}
			}
		}
		.italic {
			if file.ends_with('-Regular') {
				file = file.replace('-Regular', '-Italic')
			} else if file.starts_with('DejaVuSans') {
				file += '-Oblique'
			} else if file.to_lower().starts_with('arial') {
				file += 'i'
			} else {
				file += 'Italic'
			}
		}
		.mono {
			if !file.ends_with('Mono-Regular') && file.ends_with('-Regular') {
				file = file.replace('-Regular', 'Mono-Regular')
			} else if file.to_lower().starts_with('arial') {
				// Arial has no mono variant
			} else {
				file += 'Mono'
			}
		}
	}
	return fpath + file + '.ttf'
}
