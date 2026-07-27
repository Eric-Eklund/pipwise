extends SceneTree
## Synthesises the sound effects and writes them as WAV files.
##
##     godot --headless --script res://tools/generate_sfx.gd
##
## The project shipped with an SFX bus and no sounds to put on it. Rather than
## source six audio files, they are generated: every one here is a handful of
## sine partials under an envelope, which is all a UI blip has ever been.
##
## Written as a tool rather than baked into the game so the sounds are ordinary
## assets — replaceable one at a time by anything better, with no code change.
## Rerun it after editing a recipe; it overwrites assets/sfx/*.wav.
##
## 16-bit mono at 44.1kHz. Godot imports a bare .wav without any .import file
## needing to be written by hand.

const OUT_DIR := "res://assets/sfx"
const RATE := 44100

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# Every sound is normalised to a deliberate peak rather than to whatever its
	# recipe happened to produce. Otherwise the loudness ranking is an accident
	# of how many partials a chord has — which had hot dice, the best thing that
	# can happen in a turn, coming out as the quietest sound in the game.
	_write("take", _blip(880.0, 0.10), 0.45)
	_write("take_big", _chord([660.0, 990.0, 1320.0], 0.28), 0.62)
	_write("hot_dice", _chord([880.0, 1320.0, 1760.0, 2640.0], 0.55), 0.85)
	_write("bank", _sequence([[587.33, 0.10], [880.0, 0.30]]), 0.5)
	_write("farkle", _farkle(), 0.8)
	_write("roll", _rattle(0.34), 0.4)

	print("wrote 6 sounds to %s" % OUT_DIR)
	quit(0)

# --- recipes ---------------------------------------------------------------

## One sine under a fast attack and an exponential decay.
func _blip(frequency : float, seconds : float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var count := int(RATE * seconds)
	samples.resize(count)
	for i in count:
		var t := float(i) / float(RATE)
		samples[i] = sin(TAU * frequency * t) * _envelope(t, seconds, 0.004)
	return samples

## Several partials at once, quieter the higher they go, so the stack reads as
## one bright tone rather than a cluster.
func _chord(frequencies : Array, seconds : float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var count := int(RATE * seconds)
	samples.resize(count)
	for i in count:
		var t := float(i) / float(RATE)
		var value := 0.0
		for index in frequencies.size():
			value += sin(TAU * float(frequencies[index]) * t) / float(index + 1)
		samples[i] = value * _envelope(t, seconds, 0.005)
	return samples

## Notes one after another, each with its own envelope.
func _sequence(notes : Array) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	for note in notes:
		samples.append_array(_blip(float(note[0]), float(note[1])))
	return samples

## A tone sliding down a minor sixth into a noise burst. Two unpleasant things
## at once, which is roughly what losing three thousand points deserves.
func _farkle() -> PackedFloat32Array:
	var seconds := 0.5
	var count := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		var t := float(i) / float(RATE)
		var progress := t / seconds
		# 330Hz down to 110Hz. Integrating the frequency rather than multiplying
		# it by t is what keeps the slide smooth instead of stepping.
		var frequency : float = lerpf(330.0, 110.0, progress)
		phase += TAU * frequency / float(RATE)
		var tone := sin(phase)
		# The noise stays well under the tone. Louder and it swamps the slide,
		# which is the part that carries the "something went wrong".
		var noise := rng.randf_range(-1.0, 1.0) * progress * 0.22
		samples[i] = (tone * 0.85 + noise) * _envelope(t, seconds, 0.002)
	return samples

## Dice on a table: short noise grains, each with its own fast decay.
func _rattle(seconds : float) -> PackedFloat32Array:
	var count := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Four one-pole lowpasses in series. One was not nearly enough — raw noise
	# averaged with its previous sample still sits up around 6kHz, which is hiss
	# rather than dice. Cascading drags it down to something wooden.
	var stages : Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i in count:
		var t := float(i) / float(RATE)
		var grain := fmod(t, 0.045) / 0.045
		var value := rng.randf_range(-1.0, 1.0) * pow(1.0 - grain, 3.0)
		for stage in stages.size():
			stages[stage] = stages[stage] + (value - stages[stage]) * 0.22
			value = stages[stage]
		samples[i] = value * _envelope(t, seconds, 0.001)
	return samples

## Scales a sound so its loudest moment lands exactly on [param peak]. The
## recipes above are written for shape, not level; this is where level is
## decided, in one place, so the sounds can be ranked against each other.
func _normalise(samples : PackedFloat32Array, peak : float) -> PackedFloat32Array:
	var loudest := 0.0
	for sample in samples:
		loudest = maxf(loudest, absf(sample))
	if loudest <= 0.0:
		push_error("silent sound")
		return samples
	var gain := peak / loudest
	for i in samples.size():
		samples[i] *= gain
	return samples

## Fast attack, exponential decay. Anything slower clicks at the start.
func _envelope(t : float, seconds : float, attack : float) -> float:
	if t < attack:
		return t / attack
	var remaining := (t - attack) / maxf(0.0001, seconds - attack)
	return pow(1.0 - clampf(remaining, 0.0, 1.0), 2.2)

# --- writing ---------------------------------------------------------------

## A 16-bit mono PCM WAV. Written by hand because Godot can only *import* audio,
## not export it, and the header is 44 bytes.
func _write(name : String, samples : PackedFloat32Array, peak : float) -> void:
	samples = _normalise(samples, peak)
	var data := PackedByteArray()
	for sample in samples:
		var clipped := clampf(sample, -1.0, 1.0)
		var value := int(clipped * 32767.0)
		data.append(value & 0xFF)
		data.append((value >> 8) & 0xFF)

	var path := "%s/%s.wav" % [OUT_DIR, name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % path)
		return

	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data.size())
	file.store_buffer("WAVE".to_ascii_buffer())
	file.store_buffer("fmt ".to_ascii_buffer())
	file.store_32(16)          # subchunk size
	file.store_16(1)           # PCM
	file.store_16(1)           # mono
	file.store_32(RATE)
	file.store_32(RATE * 2)    # byte rate: rate * channels * bytes per sample
	file.store_16(2)           # block align
	file.store_16(16)          # bits per sample
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data.size())
	file.store_buffer(data)
	file.close()
	print("  %s.wav  %.2fs" % [name, float(samples.size()) / float(RATE)])
