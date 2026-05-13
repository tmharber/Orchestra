# Orchestra

A macOS terminal orchestrator for managing multiple terminal instances in a tiling layout.

## Getting Started

### Prerequisites

- macOS 15.0+
- Xcode 16+

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/tomharber/Orchestra.git
   cd Orchestra
   ```

2. Open the project in Xcode:
   ```bash
   open Orchestra.xcodeproj
   ```

3. Select your development team in the project settings and build:
   ```bash
   Product > Build
   ```

4. Run the application:
   ```bash
   Product > Run
   ```

## Usage

### Terminal Management

- **New Terminal:** Use the "+" button in the toolbar to add a new terminal.
- **Split Panes:** Drag the handles between terminal panes to split or resize them.

### Customization

- **Shell Configuration:** The application uses your system's default shell (zsh, bash, fish, etc.).
- **Sandboxing:** Terminal access is unrestricted for full compatibility with coding agents.