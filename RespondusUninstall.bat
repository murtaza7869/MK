CD /D C:\Users\student\Downloads
MD ldb2setup_2-0-8
NET USE L: \\student-server\deepfreeze\ldb2setup_2-0-8
XCOPY L:\*.* C:\Users\student\Downloads\ldb2setup_2-0-8 /E /Y
NET USE L: /delete 

CD /D C:\Users\student\Downloads\ldb2setup_2-0-8

setup /s /f1"C:\Users\student\Downloads\ldb2setup_2-0-8\unsetup.iss"
