TARGETS = Makefile Configure CHANGES README TODO bin admin-cgi cgi-bin config source htdocs lib
#VERSION=`grep 'Version =' lib/ROADS.pm|sed -e 's/.*"\(.*\)".*/\1/'`
VERSION = "v2.3"
RV = "roads-$(VERSION)"
SNAPPATH = "/home/ftp/pub/ROADS/alpha/roads-snapshot.tar.Z"

release: 
	rm -f dist.tar.Z
	$(MAKE) dist
	echo "Building $(RV)"
	rm -rf $(RV)
	mkdir $(RV)
	cd $(RV) && /usr/local/bin/tar zxvf ../dist.tar.Z && \
	  mv config config.dist && mv source source.dist
	/usr/local/bin/tar cvf $(RV).tar $(RV) && gzip -f $(RV).tar
	rm -f dist.tar.Z

dist:
	/usr/local/bin/tar --create --verbose --file dist.tar --exclude RCS \
	  --exclude '*.pod' --exclude admin-cgi/admin.pl \
	  --exclude '*.FCS' --exclude '*.safe' --exclude '*.rej' \
          --exclude '*.old' --exclude 'lib/ROADS.pm' \
          --exclude '*~' --exclude '*.dir' --exclude '*.pag' \
          --exclude '*.tex'  --exclude '*.log' --exclude '*.aux' \
          --exclude '*.orig' --exclude '*.bib' --exclude '*.fig' \
          --exclude 'OldManual' --exclude 'wppd.pid' \
          --exclude 'config/databases' --exclude config/multilingual.sosig $(TARGETS)
	compress -f dist.tar
