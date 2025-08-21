serve-dev lighttpd-cgi:
	lighttpd -D -f ./service/lighttpd-cgi.conf

lighttpd-fcgi:
	lighttpd -D -f ./service/lighttpd-fcgi.conf

cgi fcgi:
	./gorillanest -$@

run: fcgi
