#!/bin/bash

# Generate Swift code from proto files
#
# Prerequisites:
#   brew install protobuf swift-protobuf grpc-swift
#
# Usage:
#   cd RushDay/Core/Services/GRPC/Proto
#   ./generate.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../Generated"

echo "Creating output directory..."
mkdir -p "$OUTPUT_DIR"

echo "Generating Swift code from proto files..."

# Generate Swift protobuf messages and gRPC client stubs
# Using grpc-swift v1.x for iOS 13+ compatibility (v2.x requires iOS 18+)
GRPC_PLUGIN="$HOME/bin/protoc-gen-grpc-swift-1"

if [ ! -f "$GRPC_PLUGIN" ]; then
    echo "Error: grpc-swift v1.x plugin not found at $GRPC_PLUGIN"
    echo ""
    echo "To install, run:"
    echo "  cd /tmp"
    echo "  git clone --depth 1 --branch 1.23.1 https://github.com/grpc/grpc-swift.git"
    echo "  cd grpc-swift"
    echo "  swift build -c release --product protoc-gen-grpc-swift"
    echo "  mkdir -p ~/bin"
    echo "  cp .build/release/protoc-gen-grpc-swift ~/bin/protoc-gen-grpc-swift-1"
    exit 1
fi

protoc \
  --proto_path="$SCRIPT_DIR" \
  --swift_out="$OUTPUT_DIR" \
  --swift_opt=Visibility=Public \
  --plugin=protoc-gen-grpc-swift="$GRPC_PLUGIN" \
  --grpc-swift_out="$OUTPUT_DIR" \
  --grpc-swift_opt=Visibility=Public \
  --grpc-swift_opt=Client=true \
  --grpc-swift_opt=Server=false \
  "$SCRIPT_DIR"/common.proto \
  "$SCRIPT_DIR"/user.proto \
  "$SCRIPT_DIR"/event.proto \
  "$SCRIPT_DIR"/vendor.proto \
  "$SCRIPT_DIR"/invitation.proto \
  "$SCRIPT_DIR"/ai_planner.proto

echo "Generated Swift files in $OUTPUT_DIR:"
ls -la "$OUTPUT_DIR"

echo ""
echo "Done! Add the generated files to your Xcode project."
