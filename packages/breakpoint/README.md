# Breakpoint

Calculates the responsive layout grid properties (columns, gutters, and margins) based on the current screen size, following [Material Design Guidelines](https://material.io/design/layout/responsive-layout-grid.html).

---

## Features

*   **Standardized Breakpoints**: Implements the Material Design responsive layout grid system.
*   **Adaptive Properties**: providing the correct `columns` count, `glutters` spacing, and `margin` width for any screen width.
*   **Device Classification**: Identifies device types (Handset, Tablet, Desktop) and window sizes (xsmall to xlarge).
*   **Flexible Usage**: Works with both `BoxConstraints` (via LayoutBuilder) and `MediaQuery`.

## Installation

```bash
flutter pub add breakpoint
```

## Usage

### Using BreakpointBuilder

The easiest way to use this package is with `BreakpointBuilder`. It automatically handles the `LayoutBuilder` for you and provides the current `Breakpoint` data.

```dart
BreakpointBuilder(
  builder: (context, breakpoint) {
    // The breakpoint passed here provides the standardized margins,
    // columns, and gutters for the current screen size.

    return Container(
      // Access the margin, commonly 16.0 or 24.0
      padding: EdgeInsets.all(breakpoint.margin), 
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: breakpoint.columns, // 4, 8, or 12 columns
          crossAxisSpacing: breakpoint.gutters, // 16.0 or 24.0 spacing
          mainAxisSpacing: breakpoint.gutters,
        ),
        // ...
      ),
    );
  },
)
```

### Manual Calculation

If you are already inside a `LayoutBuilder` or want to use `MediaQuery`:

**From Constraints (Recommended for sub-views):**
```dart
LayoutBuilder(builder: (context, constraints) {
  // Calculate the breakpoint based on the current widget's constraints
  final breakpoint = Breakpoint.fromConstraints(constraints);
  
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: breakpoint.margin),
    child: Row(
      children: [
        // Your adaptive layout here
      ],
    ),
  );
});
```

**From MediaQuery (App-wide layout):**
```dart
// Calculate based on the full screen size
final breakpoint = Breakpoint.fromMediaQuery(context);

// Example: accessing device type
if (breakpoint.device == LayoutClass.desktop) {
  return DesktopLayout();
} else if (breakpoint.device == LayoutClass.tablet) {
  return TabletLayout();
} else {
  return MobileLayout();
}
```

## Breakpoint System

This package maps screen widths to the standard Material Design responsive grid:

| Screen Width | Device | Window | Columns | Gutters | Margins |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **0 - 359** | Small Handset | xsmall | 4 | 16dp | 16dp |
| **360 - 399** | Medium Handset | xsmall | 4 | 16dp | 16dp |
| **400 - 479** | Large Handset | xsmall | 4 | 16dp | 16dp |
| **480 - 599** | Large Handset | xsmall | 4 | 16dp | 16dp |
| **600 - 719** | Small Tablet | small | 8 | 16dp | 16dp |
| **720 - 839** | Large Tablet | small | 8 | 24dp | 24dp |
| **840 - 959** | Large Tablet | small | 12 | 24dp | 24dp |
| **960 - 1023** | Large Tablet | small | 12 | 24dp | 24dp |
| **1024 - 1279** | Desktop | medium | 12 | 24dp | 24dp |
| **1280 - 1439** | Desktop | medium | 12 | 24dp | 24dp |
| **1440 - 1599** | Desktop | large | 12 | 24dp | 24dp |
| **1600 - 1919** | Desktop | large | 12 | 24dp | 24dp |
| **1920+** | Desktop | xlarge | 12 | 24dp | 24dp |

*Note: In Landscape orientation, the effective width calculation includes a buffer (+120dp) to better align with landscape layout expectations.*

## Example

Check out the `example` directory for a full Material 3 adaptive dashboard application.
