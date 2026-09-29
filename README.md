# Ruler

A simple on-screen ruler for iPhone and iPad: centimetres on the left edge, inches (to 1/16") on the right, and a bubble level in the middle.

Unlike most ruler apps, it has an **offset** setting for your phone case. If the case adds 1.5 mm past the edge of the phone, the ruler starts at 1.5 mm instead of 0, so you can measure flush against the outside of the case.

## Reversed scales

Tap the arrow button next to the gear (or use **Zero at the bottom** in Settings) to put 0 at the bottom edge, with values increasing upward. Lay the phone flat, push the object against its bottom edge, and read the size at the top. The bottom edge has its own offset, since a case can be thicker at one end.

## Calibration

iOS doesn't tell apps the physical size of the screen, so the app starts from a best guess and lets you fine-tune it. Settings opens on first launch.

- **Calibrate with a credit card:** hold a card upright, flush with the top edge of the phone (the bottom edge when reversed). Adjust the width with **Scale**, then the card's far edge with **Offset**.
- **Calibrate manually:** set **Scale** (in ppi) and the **Top offset** and **Bottom offset** (in mm) directly, for example by checking against a real ruler.

Write down these values so you can restore them after a reset.

## Building

Open `Ruler.xcodeproj` in Xcode 16 or later and run. Requires iOS 17+. To run on a device, set your team under Signing & Capabilities.

## License

[MIT](LICENSE)
