#!/bin/bash

# Install local pre-push hooks
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash
make ci
EOF
chmod +x .git/hooks/pre-push
echo "Pre-push hook installed."