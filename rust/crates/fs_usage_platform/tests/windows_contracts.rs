#[cfg(windows)]
mod windows {
    use fs_usage_platform::path_identity_evidence;
    use std::{
        fs,
        path::PathBuf,
        time::{SystemTime, UNIX_EPOCH},
    };

    struct TempFixture {
        root: PathBuf,
    }

    impl TempFixture {
        fn new(name: &str) -> Self {
            let nanos = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .expect("system time")
                .as_nanos();
            let root = std::env::temp_dir().join(format!(
                "clean_disk_platform_{name}_{}_{}",
                std::process::id(),
                nanos
            ));
            fs::create_dir_all(&root).expect("create fixture root");
            Self { root }
        }

        fn path(&self) -> &PathBuf {
            &self.root
        }
    }

    impl Drop for TempFixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.root);
        }
    }

    #[test]
    fn windows_identity_evidence_does_not_fake_platform_file_id() {
        let fixture = TempFixture::new("identity");
        let file_path = fixture.path().join("sample.bin");
        fs::write(&file_path, [7_u8; 19]).expect("sample file");

        let evidence = path_identity_evidence(&file_path).expect("identity evidence");

        assert_eq!(evidence.platform_file_id(), None);
        assert_eq!(evidence.size_bytes(), Some(19));
        assert!(evidence.modified_unix_nanos().is_some());
        assert!(evidence.created_unix_nanos().is_some());
    }
}
