StaticImage - adding your own images
=====================================

WoW 1.12 (vanilla / Turtle WoW) can only load images that are:
  * TGA or BLP format  (PNG and JPG will NOT load)
  * sized to powers of two on each side (e.g. 64, 128, 256, 512, 1024)
      - the two sides do NOT have to match: 256x512 is fine, 300x200 is not
  * at most 1024 pixels per side

Recommended: 32-bit TGA (RGBA, uncompressed) so transparency works.
Export one from GIMP / Photoshop / Paint.NET ("Save As... .tga", 32-bit).


Where to put files
------------------
Drop your .tga / .blp files into this folder:
    Interface\AddOns\StaticImage\Media\Images\

Then in game open the config with /si , create or select an image, and set
its "Texture path" to (note: NO file extension):
    Interface\AddOns\StaticImage\Media\Images\yourfilename

Example: a file named logo.tga here becomes the path
    Interface\AddOns\StaticImage\Media\Images\logo


Rotation & clipping
-------------------
Rotation is faked with texture math, so at angles other than 0/90/180/270 the
corners of your art can be clipped by the image's rectangular bounds. To avoid
this, add transparent padding around your art (leave empty space so the rotated
corners have room). Square images rotate most cleanly.


Quick test without making a TGA
-------------------------------
You can point "Texture path" at any texture already in the game, e.g.:
    Interface\Icons\INV_Misc_QuestionMark
Handy for trying the addon before converting your own images.
