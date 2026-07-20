const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const BASE_DIR = 'd:\\AetherOS\\assets';
const SIZES = [16, 24, 32, 48, 64, 128, 256, 512];

function findSVGs(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      findSVGs(filePath, fileList);
    } else if (filePath.endsWith('.svg') && !filePath.includes('wallpapers')) {
      fileList.push(filePath);
    }
  }
  return fileList;
}

async function exportPNGs() {
  console.log('Finding SVG files...');
  const svgs = findSVGs(BASE_DIR);
  console.log(`Found ${svgs.length} SVG master files for export.`);

  let successCount = 0;
  
  for (const svgPath of svgs) {
    const dir = path.dirname(svgPath);
    const baseName = path.basename(svgPath, '.svg');
    
    for (const size of SIZES) {
      const pngPath = path.join(dir, `${baseName}-${size}.png`);
      try {
        await sharp(svgPath)
          .resize(size, size, {
            fit: 'contain',
            background: { r: 0, g: 0, b: 0, alpha: 0 }
          })
          .png()
          .toFile(pngPath);
        successCount++;
      } catch (err) {
        console.error(`Error processing ${svgPath} to size ${size}:`, err);
      }
    }
  }
  console.log(`PNG Export complete! Successfully generated ${successCount} PNG raster assets.`);
}

exportPNGs();
