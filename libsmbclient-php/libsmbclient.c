/*
   +----------------------------------------------------------------------+
   | PHP Version 4                                                        |
   +----------------------------------------------------------------------+
   | Copyright (c) 1997-2002 The PHP Group                                |
   +----------------------------------------------------------------------+
   | This source file is subject to version 2.02 of the PHP license,      |
   | that is bundled with this package in the file LICENSE, and is        |
   | available at through the world-wide-web at                           |
   | http://www.php.net/license/2_02.txt.                                 |
   | If you did not receive a copy of the PHP license and are unable to   |
   | obtain it through the world-wide-web, please send a note to          |
   | license@php.net so we can mail you a copy immediately.               |
   +----------------------------------------------------------------------+
   | Authors: Matthew Sachs <matthewg@zevils.com>                         |
   +----------------------------------------------------------------------+
 */
/* $Id$ */
#define IS_EXT_MODULE

#include "php.h"
#include "php_libsmbclient.h"

#ifdef ZTS
int libsmbclient_globals_id;
#else
#define php_libsmbclient_globals libsmbclient_globals;
#endif

#ifdef ZTS
static void php_libsmbclient_init_globals(php_libsmbclient_globals *libsmbclient_globals_p TSRMLS_DC)
{
}
#endif

function_entry libsmbclient_functions[] =
{
	PHP_FE(smbclient_test, NULL)
	{NULL, NULL, NULL}
};

zend_module_entry libsmbclient_module_entry =
{
	STANDARD_MODULE_HEADER,
	"libsmbclient",
	libsmbclient_functions,
	PHP_MINIT(smbclient),
	PHP_MSHUTDOWN(smbclient),
	PHP_RINIT(smbclient),
	NULL,
	PHP_MINFO(smbclient),
	"0.1",
	STANDARD_MODULE_PROPERTIES
};

#if COMPILE_DL_LIBSMBCLIENT
ZEND_GET_MODULE(libsmbclient)
#endif


void smbclient_auth_func(const char *server, const char *share, char *workgroup, int wglen, char *username, int userlen, char *password, int passlen) {
}


PHP_MINIT_FUNCTION(smbclient) {
	int retval;

	#ifdef ZTS
	ts_allocate_id(&libsmbclient_globals_id, sizeof(php_libsmbclient_globals), (ts_allocate_ctor) php_libsmbclient_init_globals, NULL);
	#endif

	retval = smbc_init(smbclient_auth_func, 0);
	if(retval == 0) {
		return SUCCESS;
	} else {
		switch(errno) {
			case ENOMEM: php_error_docref(NULL TSRMLS_CC, E_ERROR, "Couldn't initialize libsmbclient: Out of memory."); break;
			case ENOENT: php_error_docref(NULL TSRMLS_CC, E_ERROR, "Couldn't initialize libsmbclient: The smb.conf file would not load.  It must be located in ~/.smb/ (probably /root/.smb) ."); break;
			case EINVAL: php_error_docref(NULL TSRMLS_CC, E_ERROR, "Couldn't initialize libsmbclient: Invalid parameter."); break;
			default: php_error_docref(NULL TSRMLS_CC, E_ERROR, "Couldn't initialize libsmbclient: Unknown error (%d).", errno); break;
		}

		return FAILURE;
	}
}

PHP_RINIT_FUNCTION(smbclient) { return SUCCESS; }
PHP_MSHUTDOWN_FUNCTION(smbclient) { return SUCCESS; }

PHP_MINFO_FUNCTION(smbclient) {
	php_info_print_table_start();
	php_info_print_table_row(2, "libsmbclient Support", "enabled");
	php_info_print_table_end();
}

PHP_FUNCTION(smbclient_test)
{
	zval **parameter;

	if((ZEND_NUM_ARGS() != 1) || (zend_get_parameters_ex(1, &parameter) != SUCCESS))
	{
		WRONG_PARAM_COUNT;
	}

	convert_to_long_ex(parameter);

	RETURN_LONG((*parameter)->value.lval);
}
