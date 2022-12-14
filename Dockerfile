FROM alpine:latest

MAINTAINER MarkusMcNugen
# Forked from TommyLau for unRAID

VOLUME /config

# Install dependencies
RUN buildDeps=" \
		curl \
		g++ \
		gawk \
		geoip \
		gnutls-dev \
		gpgme \
		krb5-dev \
		libc-dev \
		libev-dev \
		libnl3-dev \
		libproxy \
		libseccomp-dev \
		libtasn1 \
		linux-headers \
		linux-pam-dev \
		lz4-dev \
		make \
		oath-toolkit-liboath \
		oath-toolkit-libpskc \
		p11-kit \
		pcsc-lite-libs \
		protobuf-c \
		readline-dev \
		scanelf \
		stoken-dev \
		tar \
		tpm2-tss-esys \
		xz \
	"; \
	set -x \
	&& apk add --update --virtual .build-deps $buildDeps \
	# The commented out line below grabs the most recent version of OC from the page which may be an unreleased version
	# && export OC_VERSION=$(curl --silent "https://ocserv.gitlab.io/www/changelog.html" 2>&1 | grep -m 1 'Version' | awk '/Version/ {print $2}') \
	# The line below grabs the 2nd most recent version of OC
	&& export OC_VERSION=1.1.6 \
	&& curl -OSL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz" \
    && curl -OSL "https://raw.githubusercontent.com/usecallmanagernz/patches/master/ocserv/cisco-webvpnlogin-$OC_VERSION.patch" \
	&& tar -xf "ocserv-$OC_VERSION.tar.xz" --strip-components=1 \
	&& rm "ocserv-$OC_VERSION.tar.xz" \
    && cd "ocserv-$OC_VERSION" \
    && patch --strip=1 < ../"cisco-webvpnlogin-$OC_VERSION.patch" \
    && cd .. \
    && mv "ocserv-$OC_VERSION" /usr/src/ocserv \
	&& cd /usr/src/ocserv \
    && rm ocserv.patch \
	&& ./configure \
	&& make \
	&& make install \
	&& cd / \
	&& rm -rf /usr/src/ocserv \
	&& runDeps="$( \
			scanelf --needed --nobanner /usr/local/sbin/ocserv \
				| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
				| xargs -r apk info --installed \
				| sort -u \
			)" \
	&& apk add --update --virtual .run-deps $runDeps gnutls-utils iptables \
	&& apk del .build-deps \
	&& rm -rf /var/cache/apk/*

RUN apk add --update bash rsync ipcalc sipcalc ca-certificates rsyslog logrotate runit \
	&& rm -rf /var/cache/apk/*

RUN update-ca-certificates

ADD ocserv /etc/default/ocserv

WORKDIR /config

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 4443
EXPOSE 4443/udp
CMD ["ocserv", "-c", "/config/ocserv.conf", "-f"]
