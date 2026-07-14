FONTS FROM neonbladeui.neuronrush.com
=====================================

The site uses two open-source Google Fonts. On your screenshot, the sidebar
menu words ("Datalines With Grid", "Ascii Rain", "Glyph City", "Cyber Circuit",
"Hexagons", "Pluviophile", "Holographic Terrain") are rendered in RAJDHANI.

  Rajdhani  -> body text + the sidebar menu you pointed at   (weights 300-700)
  Orbitron  -> headings / card titles                        (variable 400-900)

CSS on the site:
  body { font-family: var(--font-rajdhani), sans-serif; }   <- the menu font
  .font-orbitron { font-family: var(--font-orbitron); }     <- headings

WHAT'S INCLUDE
--------------
Rajdhani/
  ttf/                    Complete family, full character set (install these).
                          Light 300, Regular 400, Medium 500, SemiBold 600, Bold 700.
  web-woff2-from-site/    The exact .woff2 files served by the site (latin subset,
                          the ones that render the English menu words). Web-ready.
  OFL.txt                 License.
Orbitron/
  ttf/                    Variable font (400-900).
  web-woff2-from-site/    The exact .woff2 served by the site.
  OFL.txt                 License.
fonts.css                 Ready @font-face rules pointing at the web-woff2 files.

TO INSTALL (desktop): open the .ttf files and click Install.
TO USE ON WEB: copy the web-woff2-from-site/ files + fonts.css into your project.

LICENSE
-------
Both fonts are licensed under the SIL Open Font License 1.1 (see OFL.txt).
Free for personal and commercial use, including embedding on websites.
Rajdhani by Indian Type Foundry. Orbitron by Matt McInerney.
