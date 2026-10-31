extends RefCounted
## Gera todos os sons por código (sem arquivos de áudio externos): motor, derrapagem,
## vento, ambiente urbano, impactos, queda, cliques e jingles.

const RATE := 22050


static func engine() -> AudioStreamWAV:
	# 1 s a 80 Hz de fundamental (80 ciclos inteiros): o laço fecha sem estalo
	var n := RATE
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in n:
		var t := float(i) / RATE
		var v := sin(TAU * 80.0 * t) * 0.5
		v += sin(TAU * 160.0 * t + 0.6) * 0.35
		v += sin(TAU * 240.0 * t + 1.1) * 0.25
		v += sin(TAU * 320.0 * t + 0.2) * 0.12
		v += sin(TAU * 400.0 * t) * 0.07
		v *= 0.75 + 0.25 * sin(TAU * 20.0 * t)
		v += (rng.randf() - 0.5) * 0.08
		out[i] = v * 0.55
	return _stream(out, true)


static func skid() -> AudioStreamWAV:
	var n := RATE
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.25
		var hp := noise - lp
		out[i] = hp * 0.35 + sin(TAU * 1800.0 * t + 3.0 * sin(TAU * 7.0 * t)) * 0.18
	return _stream(_loopify(out, 400), true)


static func wind() -> AudioStreamWAV:
	return _stream(_loopify(_brown(31, 0.985, 0.12, 1.0), 800), true)


static func ambient() -> AudioStreamWAV:
	# 2 s de rumor grave de cidade
	return _stream(_loopify(_brown(47, 0.992, 0.06, 2.0), 1200), true)


static func impact() -> AudioStreamWAV:
	var n := int(RATE * 0.35)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 18.0)
		out[i] = ((rng.randf() * 2.0 - 1.0) * 0.6 + sin(TAU * 55.0 * t) * 0.9) * env
	return _stream(out, false)


static func crash() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 5.0)
		var scrape := (rng.randf() * 2.0 - 1.0) * 0.5 * exp(-t * 3.0)
		var thump := sin(TAU * 50.0 * t) * 0.9 * exp(-t * 14.0)
		var clank := sin(TAU * 420.0 * t) * 0.3 * exp(-t * 9.0)
		out[i] = (scrape + thump + clank) * (0.4 + 0.6 * env)
	return _stream(out, false)


static func click() -> AudioStreamWAV:
	var n := int(RATE * 0.07)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * 900.0 * t) * exp(-t * 55.0) * 0.6
	return _stream(out, false)


static func success() -> AudioStreamWAV:
	return _notes([523.25, 659.25, 783.99, 1046.5], 0.14)


static func fail() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * lerpf(320.0, 140.0, t / 0.6) / RATE
		out[i] = sin(phase) * exp(-t * 3.0) * 0.5
	return _stream(out, false)


static func _notes(freqs: Array, dur: float) -> AudioStreamWAV:
	var per := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(per * freqs.size())
	for k in freqs.size():
		for i in per:
			var t := float(i) / RATE
			out[k * per + i] = sin(TAU * float(freqs[k]) * t) * exp(-t * 7.0) * 0.5
	return _stream(out, false)


static func _brown(seed_value: int, decay: float, gain: float, seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := 0.0
	var peak := 0.0001
	for i in n:
		b = b * decay + (rng.randf() * 2.0 - 1.0) * gain
		out[i] = b
		peak = maxf(peak, absf(b))
	for i in n:
		out[i] = out[i] / peak * 0.7
	return out


## Faz o laço fechar sem estalo: mistura o final com o começo.
static func _loopify(src: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := src.size()
	var body := src.slice(0, n - fade)
	for i in fade:
		body[i] = lerpf(src[n - fade + i], src[i], float(i) / fade)
	return body


static func _stream(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s
