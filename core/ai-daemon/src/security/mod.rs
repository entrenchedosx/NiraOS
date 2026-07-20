use std::ffi::CString;
use std::path::Path;

pub struct SecurityManager {}

impl SecurityManager {
    pub fn drop_privileges() -> anyhow::Result<()> {
        #[cfg(target_os = "linux")]
        {
            let user_name =
                CString::new("nira-ai").map_err(|_| anyhow::anyhow!("invalid user name"))?;

            let ai_user = unsafe {
                let mut pwd: libc::passwd = std::mem::zeroed();
                let mut buf = vec![0u8; 4096];
                let mut result: *mut libc::passwd = std::ptr::null_mut();

                let ret = libc::getpwnam_r(
                    user_name.as_ptr(),
                    &mut pwd,
                    buf.as_mut_ptr() as *mut libc::c_char,
                    buf.len(),
                    &mut result,
                );

                if ret != 0 || result.is_null() {
                    anyhow::bail!(
                        "user 'nira-ai' does not exist (getpwnam_r returned {})",
                        ret
                    );
                }
                *result
            };

            let ai_uid = ai_user.pw_uid;
            let ai_gid = ai_user.pw_gid;

            // Initialize supplementary groups.
            let init_result = unsafe { libc::initgroups(user_name.as_ptr(), ai_gid) };
            if init_result != 0 {
                anyhow::bail!("initgroups failed: {}", std::io::Error::last_os_error());
            }

            // Set group ID.
            if unsafe { libc::setgid(ai_gid) } != 0 {
                anyhow::bail!("setgid failed: {}", std::io::Error::last_os_error());
            }

            // Set user ID.
            if unsafe { libc::setuid(ai_uid) } != 0 {
                anyhow::bail!("setuid failed: {}", std::io::Error::last_os_error());
            }

            // Change to home directory.
            let home = Path::new("/var/lib/niraos/ai");
            if home.exists() {
                std::env::set_current_dir(home)?;
            }

            println!(
                "[Security] privileges dropped to nira-ai (uid={}, gid={})",
                ai_uid, ai_gid
            );
        }

        #[cfg(not(target_os = "linux"))]
        {
            println!("[Security] privilege dropping not supported on this platform");
        }

        Ok(())
    }
}
