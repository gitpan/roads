TARGETS=Makefile Configure CHANGES README TODO \
        bin admin-cgi cgi-bin config source htdocs lib
#VERSION=`grep 'Version =' lib/ROADS.pm|sed -e 's/.*"\(.*\)".*/\1/'`
VERSION="v2.2"
RV="roads-$(VERSION)"
SNAPPATH="/home/ftp/pub/ROADS/alpha/roads-snapshot.tar.Z"

all:
	perl ./Configure

dist:
	/usr/local/bin/tar --create --verbose --file dist.tar --exclude RCS \
		--exclude '*.pod' --exclude admin-cgi/admin.pl \
		--exclude '*.FCS' --exclude '*.safe' \
		--exclude '*.old' --exclude 'lib/ROADS.pm' \
		--exclude '*~' --exclude '*.dir' --exclude '*.pag' \
		--exclude '*.tex'  --exclude '*.log' --exclude '*.aux' \
		--exclude '*.bib' --exclude '*.fig' \
		--exclude 'OldManual' --exclude 'wppd.pid' \
		--exclude 'config/databases' $(TARGETS)
	compress -f dist.tar

release:
	rm -f dist.tar.Z
	$(MAKE) dist
	echo "Building $(RV)"
	rm -rf $(RV)
	mkdir $(RV)
	cd $(RV) && /usr/local/bin/tar zxvf ../dist.tar.Z && \
	  mv config config.dist && mv source source.dist
	/usr/local/bin/tar cvf $(RV).tar $(RV) && compress -f $(RV).tar
	rm -f dist.tar.Z

snapshot:
	$(MAKE) release
	echo "Installing snapshot"
	rm -rf $(SNAPPATH)
	mv $(RV).tar.Z $(SNAPPATH)
