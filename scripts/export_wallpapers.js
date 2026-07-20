const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const WALLPAPER_DIR = 'd:\\AetherOS\\assets\\wallpapers';

async function exportWallpapers() {
  const files = fs.readdirSync(WALLPAPER_DIR).filter(f => f.endsWith('.svg'));
  console.log(`Found ${files.length} 4K Wallpapers to export.`);
  
  let count = 0;
  for (const file of files) {
    const svgPath = path.join(WALLPAPER_DIR, file);
    const baseName = path.basename(file, '.svg');
    const pngPath = path.join(WALLPAPER_DIR, `${baseName}.png`);
    const jpgPath = path.join(WALLPAPER_DIR, `${baseName}.jpg`);
    
    try {
      const img = sharp(svgPath);
      await img.clone().png().toFile(pngPath);
      await img.clone().jpeg({ quality: 90 }).toFile(jpgPath);
      count++;
    } catch (err) {
      console.error(`Failed to export ${file}:`, err);
    }
  }
  
  console.log(`Exported ${count} wallpapers to PNG and JPG.`);
}

exportWallpapers();
