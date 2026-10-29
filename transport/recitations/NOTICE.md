# On-board Quran recitation

Reciter: **Sheikh Abdulrahman Al-Sudais**, as identified by MP3Quran.
Collection: https://www.mp3quran.net/eng/sds
Audio source: https://cdn.mp3quran.net/audio/abdulrahman-sudais/r1/

The bundled files contain complete short surahs **103–114**, Al-Asr through An-Nas, transcoded from the source MP3 files to Ogg Vorbis for local Godot/browser playback. No synthetic voice, pitch alteration or music is applied to the recitation. Original source URLs, source SHA-256 hashes, output hashes and durations are retained in `sources.json`; `tools/prepare_recitations.py` reproduces the conversion. The source recordings retain their third-party rights and attribution and are not claimed as original MIT game assets.

Each of the twelve buses starts with a different surah. Playback belongs to one local listener, starts only while the controlled playable character is on that bus, and stops when they leave or turn it off. One surah plays at a time, with the next beginning only after completion or the passenger's Next surah action. No external request is required during play.
