Nltest /sc_change_pwd:mkdomain.test >C:\windows\temp\reset_trust.txt
ping localhost -n 5
nltest /sc_verify:mkdomain.test >C:\windows\temp\Verify_trust.txt
