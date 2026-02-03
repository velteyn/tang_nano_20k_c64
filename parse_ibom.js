const fs = require('fs');
const LZString = require('lz-string');

const fileName = process.argv[2];
const searchTerm = process.argv[3];

if (!fileName) {
    console.log("Usage: node parse_ibom.js <file> [search_term]");
    process.exit(1);
}

console.log(`Reading ${fileName}...`);
const content = fs.readFileSync(fileName, 'utf8');

const match = content.match(/var pcbdata = JSON.parse\('(.+?)'\)/);

if (match) {
    console.log("Found compressed data. Decompressing...");
    let jsonStr = LZString.decompressFromBase64(match[1]);
    
    if (searchTerm) {
        console.log(`Searching for '${searchTerm}'...`);
        let index = jsonStr.indexOf(searchTerm);
        while (index !== -1) {
            console.log(`Found at ${index}`);
            const start = Math.max(0, index - 100);
            const end = Math.min(jsonStr.length, index + 100);
            console.log("Context:", jsonStr.substring(start, end));
            index = jsonStr.indexOf(searchTerm, index + 1);
        }
    } else {
        // Default search if no term provided
        const terms = ["M0S", "SPI", "CLK", "RST", "T10", "P16", "H11", "J8", "BL616", "BL702", "JTAG"];
        terms.forEach(term => {
             const idx = jsonStr.indexOf(term);
             if (idx !== -1) {
                 console.log(`Found '${term}' at ${idx}`);
                 console.log("Context:", jsonStr.substring(idx - 50, idx + 50));
             } else {
                 console.log(`'${term}' not found.`);
             }
        });
    }

} else {
    console.log("Could not find pcbdata.");
}
