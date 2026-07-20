use std::fs;
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;

const GGUF_MAGIC: [u8; 4] = [0x47, 0x47, 0x55, 0x46]; // "GGUF" in ASCII

#[derive(Debug)]
pub struct GgufHeader {
    pub version: u32,
    pub tensor_count: u64,
    pub metadata_kv_count: u64,
    pub total_size_bytes: u64,
}

pub struct Validator {}

impl Validator {
    pub fn new() -> Self {
        Self {}
    }

    pub fn validate_gguf(path: &Path) -> anyhow::Result<GgufHeader> {
        if !path.exists() {
            anyhow::bail!("file does not exist: {}", path.display());
        }

        let metadata = fs::metadata(path)?;
        let file_size = metadata.len();
        if file_size < 16 {
            anyhow::bail!(
                "file too small for GGUF header: {} bytes (minimum 16)",
                file_size
            );
        }

        let mut file = fs::File::open(path)
            .map_err(|e| anyhow::anyhow!("cannot open {}: {}", path.display(), e))?;

        // Read magic bytes (4 bytes)
        let mut magic = [0u8; 4];
        file.read_exact(&mut magic)
            .map_err(|e| anyhow::anyhow!("failed to read magic bytes: {}", e))?;

        if magic != GGUF_MAGIC {
            anyhow::bail!(
                "invalid GGUF magic: expected 'GGUF' (0x47475546), got {:02x?}",
                magic
            );
        }

        // Read version (uint32 LE)
        let mut version_bytes = [0u8; 4];
        file.read_exact(&mut version_bytes)?;
        let version = u32::from_le_bytes(version_bytes);
        if version < 1 || version > 3 {
            anyhow::bail!("unsupported GGUF version: {} (expected 1-3)", version);
        }

        // Read tensor_count (uint64 LE)
        let mut tensor_bytes = [0u8; 8];
        file.read_exact(&mut tensor_bytes)?;
        let tensor_count = u64::from_le_bytes(tensor_bytes);

        // Read metadata_kv_count (uint64 LE)
        let mut kv_bytes = [0u8; 8];
        file.read_exact(&mut kv_bytes)?;
        let metadata_kv_count = u64::from_le_bytes(kv_bytes);

        // Minimum header size is 24 bytes (magic + version + tensor_count + kv_count)
        // Full header size depends on the key-value metadata that follows.
        // We don't decode every KV pair but verify the file is at least as large
        // as the header claims.
        let header = GgufHeader {
            version,
            tensor_count,
            metadata_kv_count,
            total_size_bytes: file_size,
        };

        // Seek to end of header by reading through KV pairs to find tensor data offset.
        // Each KV pair: key (string length + data) + value type + value data.
        // For simplicity, we verify we can seek to the position the header claims.
        let mut pos: u64 = 4 + 4 + 8 + 8; // magic(4) + version(4) + tensor_count(8) + kv_count(8)

        for i in 0..metadata_kv_count {
            if pos >= file_size {
                anyhow::bail!(
                    "GGUF metadata KV pair {} extends beyond file at byte {}",
                    i,
                    pos
                );
            }

            // Read key string length (uint64 LE)
            file.seek(SeekFrom::Start(pos))?;
            let mut key_len_bytes = [0u8; 8];
            file.read_exact(&mut key_len_bytes)?;
            let key_len = u64::from_le_bytes(key_len_bytes) as u64;
            pos += 8 + key_len;

            // Read value type (uint32 LE)
            if pos + 4 > file_size {
                anyhow::bail!("GGUF metadata value type out of bounds at byte {}", pos);
            }
            file.seek(SeekFrom::Start(pos))?;
            let mut val_type_bytes = [0u8; 4];
            file.read_exact(&mut val_type_bytes)?;
            let val_type = u32::from_le_bytes(val_type_bytes);
            pos += 4;

            // Value size depends on type:
            // 0=uint8, 1=int8, 2=uint16, 3=int16, 4=uint32, 5=int32,
            // 6=float32, 7=bool, 8=string, 9=array, 10=uint64, 11=int64,
            // 12=float64, 13=float16, 14=brain16
            let val_size = match val_type {
                0 | 1 => 1u64,
                2 | 3 => 2,
                4 | 5 | 6 => 4,
                7 => 1,
                8 => {
                    // string: uint64 length + data
                    if pos + 8 > file_size {
                        anyhow::bail!("GGUF string value length out of bounds at byte {}", pos);
                    }
                    file.seek(SeekFrom::Start(pos))?;
                    let mut str_len_bytes = [0u8; 8];
                    file.read_exact(&mut str_len_bytes)?;
                    let str_len = u64::from_le_bytes(str_len_bytes);
                    8 + str_len
                }
                9 => {
                    // array: uint32 type + uint64 count + elements
                    if pos + 4 + 8 > file_size {
                        anyhow::bail!("GGUF array header out of bounds at byte {}", pos);
                    }
                    file.seek(SeekFrom::Start(pos))?;
                    let mut arr_type_bytes = [0u8; 4];
                    file.read_exact(&mut arr_type_bytes)?;
                    let mut arr_count_bytes = [0u8; 8];
                    file.read_exact(&mut arr_count_bytes)?;
                    let _arr_type = u32::from_le_bytes(arr_type_bytes);
                    let arr_count = u64::from_le_bytes(arr_count_bytes);
                    4 + 8 + arr_count * 4 // simplified: assumes array element size 4
                }
                10 | 11 | 12 => 8,
                13 | 14 => 2,
                _ => anyhow::bail!("unknown GGUF metadata value type: {}", val_type),
            };
            pos += val_size;

            if pos > file_size {
                anyhow::bail!("GGUF metadata KV pair {} exceeds file at byte {}", i, pos);
            }
        }

        println!(
            "[Validator] GGUF file OK: version={}, tensors={}, metadata entries={}, size={} MB",
            header.version,
            header.tensor_count,
            header.metadata_kv_count,
            file_size / 1024 / 1024
        );

        Ok(header)
    }
}

impl Default for Validator {
    fn default() -> Self {
        Self::new()
    }
}
