#!/bin/bash

# CS:GO Enhanced Sprays Installation Script
# Enhanced version of SM Franug CSGO Sprays with graffiti balloon animation

echo "========================================"
echo "CS:GO Enhanced Sprays Installation"
echo "========================================"

# Check if SourceMod compiler exists
if [ ! -f "addons/sourcemod/scripting/spcomp" ]; then
    echo "❌ SourceMod compiler not found!"
    echo "Please make sure you have SourceMod installed in the current directory."
    exit 1
fi

echo "🔨 Compiling franug_sprays_enhanced.sp..."

# Compile the plugin
./addons/sourcemod/scripting/spcomp franug_sprays_enhanced.sp -o addons/sourcemod/plugins/franug_sprays_enhanced.smx

if [ $? -eq 0 ]; then
    echo "✅ Plugin compiled successfully!"
else
    echo "❌ Compilation failed!"
    exit 1
fi

# Create directory structure for model files
echo "📁 Creating directory structure..."
mkdir -p models/12konsta/graffiti/
mkdir -p materials/Models/12konsta/graffiti/

echo "📋 Required files checklist:"
echo "==========================="

# Check for required files
FILES_TO_CHECK=(
    "models/12konsta/graffiti/v_ballon4ik.mdl"
    "materials/Models/12konsta/graffiti/v_ballon4ik.vmt"
    "materials/Models/12konsta/graffiti/v_ballon4ik.vtf"
)

for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (MISSING)"
    fi
done

echo ""
echo "📝 Installation Notes:"
echo "====================="
echo "1. Copy the compiled plugin to your server:"
echo "   addons/sourcemod/plugins/franug_sprays_enhanced.smx"
echo ""
echo "2. Make sure these model files are in your server:"
echo "   - models/12konsta/graffiti/v_ballon4ik.mdl"
echo "   - materials/Models/12konsta/graffiti/v_ballon4ik.vmt"
echo "   - materials/Models/12konsta/graffiti/v_ballon4ik.vtf"
echo ""
echo "3. Configure the spray decals:"
echo "   addons/sourcemod/configs/csgo-sprays/sprays.cfg"
echo ""
echo "4. ConVar to control animation:"
echo "   sm_csgosprays_enable_animation 1"
echo ""
echo "🎯 Features:"
echo "============"
echo "• ✨ Graffiti balloon animation during spraying"
echo "• 🔧 Full compatibility with custom_weapons.sp"
echo "• ⚡ Smart viewmodel restoration"
echo "• 🎮 Configurable animation on/off"
echo ""
echo "🎮 Commands:"
echo "============"
echo "• !spray or sm_spray - Create a spray"
echo "• !sprays or sm_sprays - Choose spray from menu"
echo ""
echo "⚙️ Configuration:"
echo "=================="
echo "The plugin will auto-generate config file:"
echo "cfg/sourcemod/plugin.franug_sprays_enhanced.cfg"
echo ""
echo "✅ Installation script completed!"
echo "Don't forget to restart your server after copying the files."