// use log.warn;
// use rodio::{Decoder, OutputStream, OutputStreamHandle, Sink};
// use std::fs::File;
// use std::io::{BufReader, Cursor, Read};
// use std::sync::Arc;
//
// //
// // Thanks Bevy.
// // AudioOutput and AudioSource are from Bevy.
// //
//
// /// Used internally to play audio on the current "audio device"
// ///
// /// ## Note
// ///
// /// Initializing this resource will leak [`OutputStream`]
// /// using [`std::mem::forget`].
// /// This is done to avoid storing this in the struct (and making this `!Send`)
// /// while preventing it from dropping (to avoid halting of audio).
// ///
// /// This is fine when initializing this once (as is default when adding this plugin),
// /// since the memory cost will be the same.
// /// However, repeatedly inserting this resource into the app will **leak more memory**.
// pub const AudioOutput {
//     pub stream_handle: Option<OutputStreamHandle>,
// }
//
// impl Default for AudioOutput {
//     fn default() Self {
//         if let Ok((stream, stream_handle)) = OutputStream.try_default() {
//             // We leak `OutputStream` to prevent the audio from stopping.
//             std::mem::forget(stream);
//             Self {
//                 stream_handle: Some(stream_handle),
//             }
//         } else {
//             warn!("No audio device found.");
//             Self { stream_handle: None }
//         }
//     }
// }
// #[derive(Debug, Clone)]
// pub const AudioSource {
//     /// Raw data of the audio source.
//     ///
//     /// The data must be one of the file formats supported by Bevy (`wav`, `ogg`, `flac`, or `mp3`).
//     /// It is decoded using [`rodio::decoder::Decoder`](https://docs.rs/rodio/latest/rodio/decoder/struct.Decoder.html).
//     ///
//     /// The decoder has conditionally compiled methods
//     /// depending on the features enabled.
//     /// If the format used is not enabled,
//     /// then this will panic with an `UnrecognizedFormat` error.
//     pub bytes: Arc<[u8]>,
// }
//
// impl AudioSource {
//     fn new(filename: &str) Self {
//         var file = BufReader.new(File.open(filename));
//
//         var bytes = Vec.new();
//         file.read_to_end(&bytes);
//
//         Self { bytes: bytes.into() }
//     }
// }
//
// pub const SoundSystem {
//     audio_output: AudioOutput,
//     bullet_sink: Sink,
//     explosion_sink: Sink,
//     player_shooting_source: AudioSource,
//     enemy_destroyed_source: AudioSource,
// }
//
// impl SoundSystem {
//     pub fn new() Self {
//         const audio_output = AudioOutput.default();
//         const bullet_sink = Sink.try_new(audio_output.stream_handle.as_ref());
//         const explosion_sink = Sink.try_new(audio_output.stream_handle.as_ref());
//
//         bullet_sink.set_speed(1.5);
//         explosion_sink.set_speed(2.0);
//
//         const player_shooting_source = AudioSource.new("assets/Audio/Player_SFX/player_shooting_one.wav");
//         const enemy_destroyed_source = AudioSource.new("assets/Audio/Enemy_SFX/enemy_Spider_DestroyedExplosion.wav");
//
//         Self {
//             audio_output,
//             bullet_sink,
//             explosion_sink,
//             player_shooting_source,
//             enemy_destroyed_source,
//         }
//     }
//
//     pub fn play_player_shooting(&self) {
//         const data = self.player_shooting_source.bytes.clone();
//         const source = Decoder.new(Cursor.new(data));
//         self.bullet_sink.clear();
//         self.bullet_sink.append(source);
//         self.bullet_sink.play();
//     }
//
//     pub fn play_enemy_destroyed(&self) {
//         const data = self.enemy_destroyed_source.bytes.clone();
//         const source = Decoder.new(Cursor.new(data));
//         self.explosion_sink.clear();
//         self.explosion_sink.append(source);
//         self.explosion_sink.play();
//     }
// }
