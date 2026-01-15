[![Buy Me A Coffee](https://img.shields.io/badge/Donate-Buy%20Me%20A%20Coffee-yellow.svg)](https://www.buymeacoffee.com/rodydavis)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=WSH3GVC49GNNJ)
![github pages](https://github.com/rodydavis/dynamic_tabs/workflows/github%20pages/badge.svg)
[![GitHub stars](https://img.shields.io/github/stars/rodydavis/dynamic_tabs?color=blue)](https://github.com/rodydavis/dynamic_tabs)
[![dynamic_tabs](https://img.shields.io/pub/v/dynamic_tabs.svg)](https://pub.dev/packages/dynamic_tabs)

# dynamic_tabs

A Flutter plugin for letting the user edit the bottom tabs like the Cupertino iTunes App.

Online demo [here](https://rodydavis.github.io/dynamic_tabs/)!

## Getting Started

- Set `persistIndex` to `true` for saving the index of the current tab to disk, every time the app launches it will open the last tab opened
- Tags must be set for each item and must be unique
- There are 2 Modes `DynamicTabScaffold.adaptive` and `DynamicTabScaffold`. The latter just show material
- When using `adaptive` mode the iOS Platform will be wrapped in a CupertinoTabBar and CupertinoTabView, this means that the navigation can be preserved per tab and that the nav bar will be shown still on push. On Android it will push the whole screen
- This widget allows you to use a stateless widget for navigation
- This supports Dark Mode
- If there are more than 5 Tabs there will be a 5th Tab Created Call "More" and it will show a list of the remaining tabs
- On the edit screen the user can reorder that tabs to the nav bar as they wish, this will also be saved to disk
- If Using `.adaptive` Cupertino Widgets are Required and YOu will have to provide the routes for the Navigator.
- You can set the max number of tabs

## Screenshots

![](https://github.com/rodydavis/plugins/blob/master/packages/dynamic_tabs/screenshots/1.PNG)
![](https://github.com/rodydavis/plugins/blob/master/packages/dynamic_tabs/screenshots/2.PNG)
![](https://github.com/rodydavis/plugins/blob/master/packages/dynamic_tabs/screenshots/3.PNG)
![](https://github.com/rodydavis/plugins/blob/master/packages/dynamic_tabs/screenshots/4.PNG)
![](https://github.com/rodydavis/plugins/blob/master/packages/dynamic_tabs/screenshots/5.PNG)
![](https://github.com/rodydavis/plugins/blob/master/packages/dynamic_tabs/screenshots/6.PNG)
