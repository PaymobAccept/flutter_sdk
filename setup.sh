#!/bin/bash

# Paymob Flutter SDK - Quick Setup Script
# This script helps you set up the plugin structure

echo "🚀 Paymob Flutter SDK Setup"
echo "================================"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null
then
    echo "❌ Flutter is not installed. Please install Flutter first."
    echo "Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter is installed"
echo ""

# Create plugin structure
echo "📁 Creating plugin structure..."

# Create the plugin
flutter create --template=plugin --platforms=android,ios paymob_flutter_sdk
cd paymob_flutter_sdk

echo "✅ Plugin structure created"
echo ""

# Create necessary directories
echo "📁 Creating additional directories..."
mkdir -p lib/src/models
mkdir -p example/lib

echo "✅ Directories created"
echo ""

echo "📝 Next Steps:"
echo "================================"
echo ""
echo "1. Copy the generated files to your plugin directory:"
echo "   - Copy all files from the 'paymob_flutter_sdk' folder"
echo ""
echo "2. Update the following files with your information:"
echo "   - pubspec.yaml (add your GitHub URL)"
echo "   - LICENSE (add your name)"
echo "   - README.md (verify all information)"
echo ""
echo "3. Test your plugin:"
echo "   cd example"
echo "   flutter run"
echo ""
echo "4. Validate your package:"
echo "   flutter pub publish --dry-run"
echo ""
echo "5. Publish to pub.dev:"
echo "   flutter pub publish"
echo ""
echo "📖 For detailed instructions, see PUBLISHING_GUIDE.md"
echo ""
echo "✅ Setup complete! Happy coding! 🎉"
