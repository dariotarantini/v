// Copyright (c) 2019-2022 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module rand

struct ReadError {
	msg  string = 'crypto.rand.read() error reading random bytes'
	code int
}
