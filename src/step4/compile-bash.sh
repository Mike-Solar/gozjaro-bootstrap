#!/bin/bash

# Set environment variables
export LFS=/mnt/lfs
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-gozjaro-linux-gnu

cd "$LFS/sources" || exit 1

# Extract Bash source package
BASH_ARCHIVE=$(ls bash-*.tar.gz)
if [ ! -f "$BASH_ARCHIVE" ]; then
    echo "Error: Bash source package not found"
    exit 1
fi

tar xf "$BASH_ARCHIVE"
BASH_DIR=$(ls -d bash-*/ | head -n1)
cd "$BASH_DIR" || exit 1

# Apply patch directly to mkbuiltins.c in the builtins directory
cat > builtins/mkbuiltins.c.patch << 'EOF'
--- builtins/mkbuiltins.c.orig
+++ builtins/mkbuiltins.c
@@ -59,7 +59,8 @@
 #define streq(a, b)	((a) && (b) && (strcmp ((a), (b)) == 0)
 #define strneq(a, b, n)	((a) && (b) && (strncmp ((a), (b), (n)) == 0)
 
-static char *xmalloc (), *xrealloc ();
+static char *xmalloc (size_t);
+static char *xrealloc (void *, size_t);
 #define savestring(x) strcpy (xmalloc (1 + strlen (x)), (x))
 
 #define STRUCT_DECLARATION_FILENAME "builtins.h"
@@ -204,18 +205,18 @@
 void array_free ();
 void free_builtin ();
 void free_defs ();
-void extract_info ();
-void write_file_headers ();
-void write_file_footers ();
-void write_builtins ();
-void write_longdocs ();
-void write_ifdefs ();
-void write_endifs ();
-void write_documentation ();
+void extract_info (char *, FILE *, FILE *);
+void write_file_headers (FILE *, FILE *);
+void write_file_footers (FILE *, FILE *);
+void write_builtins (DEF_FILE *, FILE *, FILE *);
+void write_longdocs (FILE *, ARRAY *);
+void write_ifdefs (FILE *, char **);
+void write_endifs (FILE *, char **);
+void write_documentation (FILE *, char **, int, int);
 void write_dummy_declarations ();
-void file_error ();
-void line_error ();
-void must_be_building ();
+void file_error (char *);
+void line_error (DEF_FILE *, char *, ...);
+void must_be_building (char *, DEF_FILE *);
 void add_documentation ();
 
 static char *get_arg ();
@@ -1043,9 +1044,8 @@
   exit (1);
 }
 
-static char *
-xmalloc (bytes)
-     int bytes;
+char *
+xmalloc (size_t bytes)
 {
   char *temp = (char *)malloc (bytes);
 
@@ -1055,10 +1055,8 @@
   return temp;
 }
 
-static char *
-xrealloc (pointer, bytes)
-     char *pointer;
-     int bytes;
+char *
+xrealloc (void *pointer, size_t bytes)
 {
   char *temp = (char *)realloc (pointer, bytes);
 
@@ -1081,8 +1079,7 @@
 }
 
 static void
-remove_trailing_whitespace (string)
-     char *string;
+remove_trailing_whitespace (char *string)
 {
   int i;
 
@@ -1093,8 +1090,7 @@
 }
 
 static void
-strip_whitespace (string)
-     char *string;
+strip_whitespace (char *string)
 {
   char *p;
 
EOF

# Apply the patch directly to the correct file
patch -N builtins/mkbuiltins.c builtins/mkbuiltins.c.patch

# Configure
./configure \
    --prefix=/usr \
    --build=$(sh support/config.guess) \
    --host="$LFS_TGT" \
    --without-bash-malloc \
    bash_cv_strtold_broken=no || exit 1

# Build
make || exit 1

# Install
make DESTDIR="$LFS" install || exit 1

# Create sh symlink
mkdir -pv "$LFS/bin"
ln -sv bash "$LFS/bin/sh"

echo "Bash compilation and installation completed"