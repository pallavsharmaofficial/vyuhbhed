# Background photographs

Six photographs, one per screen mood. All are **CC0 / public domain** — no
attribution is legally required, which is why the app ships no credits screen.
They are listed here anyway, because not being obliged to say where something
came from is a poor reason not to know.

Each was cropped to 9:16, desaturated, and compressed into a luminance window
of roughly 78–178. That window is not a style choice: text sits directly on
these under a translucent veil, and it is the range that keeps contrast above
4.5:1 in *both* the light and dark themes. See `tool/backgrounds.py`.

| screen | why this image | licence | source |
|---|---|---|---|
| `welcome` | dawn over a ridgeline — the morning you decide to start | CC0 | [Silhouette mountain range and yellow sky (Un](https://commons.wikimedia.org/wiki/File:Silhouette_mountain_range_and_yellow_sky_(Unsplash).jpg) |
| `today` | a path into fog: you can see the next few steps, not the end | CC0 | [Misty path (Unsplash).jpg](https://commons.wikimedia.org/wiki/File:Misty_path_(Unsplash).jpg) |
| `working` | light trails — effort in motion, the applications going out | CC0 | [Night city traffic (Unsplash).jpg](https://commons.wikimedia.org/wiki/File:Night_city_traffic_(Unsplash).jpg) |
| `aware` | weather coming in, for the screens that name a hard moment | CC0 | [Ominous clouds over mountains (Unsplash).jpg](https://commons.wikimedia.org/wiki/File:Ominous_clouds_over_mountains_(Unsplash).jpg) |
| `calm` | still water — the day is done, close the app | CC0 | [Beautiful mountain reflection (Unsplash).jpg](https://commons.wikimedia.org/wiki/File:Beautiful_mountain_reflection_(Unsplash).jpg) |
| `origin` | distance and scale, for looking back at why you started | CC0 | [China's mist mountain (Unsplash).jpg](https://commons.wikimedia.org/wiki/File:China%27s_mist_mountain_(Unsplash).jpg) |

## Re-generating them

```bash
python3 tool/backgrounds.py
```

The script refuses any licence that is not CC0 or public domain, and prints
the measured contrast for every image in both themes.
