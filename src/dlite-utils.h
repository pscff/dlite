#ifndef _DLITE_UTILS_H
#define _DLITE_UTILS_H

/**
  @file
  @brief Main header file for dlite
*/

#define DLITE_UUID_LENGTH 36  /*!< length of an uuid (excl. NUL-termination) */

#include "dlite-type.h"


/**
  @name General dlite utility functions
  @{
 */

/**
  Writes an UUID to \a buff based on \a id.

  Whether and what kind of UUID that is generated depends on \a id:
    - If \a id is NULL or empty, a new random version 4 UUID is generated.
    - If \a id is not a valid UUID string, a new version 5 sha1-based UUID
      is generated from \a id using the DNS namespace.
    - Otherwise is \a id already a valid UUID and it is simply copied to
      \a buff.

  Length of \a buff must at least (DLITE_UUID_LENGTH + 1) bytes (36 bytes
  for UUID + NUL termination).

  Returns the UUID version if a new UUID is generated or zero if \a id
  is already a valid UUID.  On error, -1 is returned.
 */
int dlite_get_uuid(char *buff, const char *id);


/**
  Returns an unique uri for metadata defined by \a name, \a version
  and \a namespace as a newly malloc()'ed string or NULL on error.

  The returned url is constructed as follows:

      namespace/version/name
 */
char *dlite_join_meta_uri(const char *name, const char *version,
                          const char *namespace);

/**
  Splits \a metadata uri into its components.  If \a name, \a version and/or
  \a namespace are not NULL, the memory they points to will be set to a
  pointer to a newly malloc()'ed string with the corresponding value.

  Returns non-zero on error.
*/
int dlite_split_meta_uri(const char *uri, char **name, char **version,
                         char **namespace);

/** @} */


/**
  @name Parsing options
  @{
 */

/** Struct used by dlite_getopt() */
typedef struct _DLiteOpt {
  int c;              /*!< Integer identifier for this option */
  const char *key;    /*!< Option key */
  const char *value;  /*!< Option value, initialised with default value */
} DLiteOpt;

/**
  Parses the options string `options` and assign corresponding values
  of the array `opts`.  The options string should be a valid url query
  string of the form:

      key1=value1;key2=value2...

  where the values are terminated by NUL or any of the characters in ";&#".
  A hash (#) terminates the options.

  `opts` should be a NULL-terminated DLiteOpt array initialised with
  default values.  At return, the values of the provided options are
  updated.

  If `modify` is non-zero, `options` is modifies such that all values in
  `opts` are NUL-terminated.  Otherwise they may be terminated by any of
  the characters in ";&#".

  Returns non-zero on error.

  Example
  -------
  If the `opts` array only contains a few elements, accessing it by index
  is probably the most convinient.  However, if it contains many elements,
  switch might be a better option using the following pattern:

      int i;
      DLiteOpt opts[] = {
        {"key1", "default1", '1'},
        {"key2", "default2", 'b'},
        {NULL, NULL}
      };
      dlite_getopt(options, opts, 0);
      for (i=0; opts[i].key; i++) {
        switch (opts[i].c) {
        case '1':
          // process option key1
          break;
        case 'b':
          // process option key2
          break;
        }
      }
 */
int dlite_option_parse(char *options, DLiteOpt *opts, int modify);



/** @} */


#endif /* _DLITE_UTILS_H */
