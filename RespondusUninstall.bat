NET USE R: /delete /y
CD /D C:\Users\student\Downloads
MD ldb2setup_2-0-8
NET USE L: "\\student-server\deepfreeze\ldb2setup_2-0-8" pima /user:localhost\student /persistent:no
Start XCOPY L:\*.* "C:\Users\student\Downloads\ldb2setup_2-0-8" /E /Y
ping localhost -n 10
NET USE L: /delete /y
NET USE R: "\\student-server\respiratory" pima /user:localhost\student /persistent:yes

CD /D C:\Users\student\Downloads\ldb2setup_2-0-8

setup /s /f1"C:\Users\student\Downloads\ldb2setup_2-0-8\unsetup.iss"
