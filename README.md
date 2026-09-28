# Ruler

A simple on-screen ruler for iPhone and iPad: centimetres on the left edge, inches (to 1/16") on the right, and a bubble level in the middle.

Unlike most ruler apps, it has an **offset** setting for your phone case. If the case adds 1.5 mm past the edge of the phone, the ruler starts at 1.5 mm instead of 0, so you can measure flush against the outside of the case.

## Calibration

iOS doesn't tell apps the physical size of the screen, so the app starts from a best guess and lets you fine-tune it. Settings opens on first launch.

- **Calibrate with a credit card:** hold a card upright, flush with the top edge of the phone. Adjust the width with **Scale**, then the bottom edge with **Offset**.
- **Calibrate manually:** set **Scale** (in ppi) and **Offset** (in mm) directly, for example by checking against a real ruler.

Write down both values so you can restore them after a reset.

## Building

Open `Ruler.xcodeproj` in Xcode 16 or later and run. Requires iOS 17+. To run on a device, set your team under Signing & Capabilities.

## License

[MIT](LICENSE)
