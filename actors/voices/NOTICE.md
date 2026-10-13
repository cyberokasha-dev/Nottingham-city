# Synthetic dialogue voice credits

The dialogue text is original to Nottingham City. `alba.ogg` and `joe.ogg` contain synthetic speech rendered locally with the MIT-licensed Piper 2023.11.14-2 runtime and the Piper Alba-medium and Joe-medium models. No voice model or runtime binary is redistributed in the game. These recordings do not depict the user speaking.

Piper project: https://github.com/rhasspy/piper
Models: https://huggingface.co/rhasspy/piper-voices

Alba model card is preserved in `ALBA-MODEL-CARD.md`. Its training corpus is the **Alba speech corpus**, Cassia Valentini-Botinhao and Junichi Yamagishi (2019), University of Edinburgh, https://doi.org/10.7488/ds/2506 and https://datashare.ed.ac.uk/handle/10283/3270. The model card identifies the corpus as CC BY 4.0: https://creativecommons.org/licenses/by/4.0/. The game clips are newly synthesized speech using original text, encoded to Ogg Vorbis and slightly pitch-varied per resident. Attribution is retained with these clips.

Joe model card is preserved in `JOE-MODEL-CARD.md`. The model card identifies its dataset as CC0, from https://github.com/OHF-Voice/voice-datasets, and notes fine-tuning from Lessac-medium. Model cards and provenance are retained rather than treating the third-party voices as the repository's original code.

`tools/prepare_voices.py` renders ten phrases in each voice and generates the timing catalog. File hashes are recorded below.

- alba.ogg SHA-256: `9503665eb453871718fbe23435412a36333deeef18bc4c81475658f21e28bc50`.

- joe.ogg SHA-256: `55baaec2a81dc60eeb9779b6f646ea6caf8a100d8f7d718961cf9518a2dbbc83`.
