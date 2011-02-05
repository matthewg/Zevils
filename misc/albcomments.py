#!/usr/bin/python

import ConfigParser
import cookielib
import getpass
import optparse
import os
import re
import sys
import urllib
import urllib2


## High-level commands

def getFriends(accessToken, appID, appSecret):
    # /me/friends
    pass


def getAlbums(friend, accessToken, appID, appSecret):
    pass


def getComments(friend, album, accessToken, appID, appSecret):
    pass



## FB graph API helper routines

def fbGetObject(id, accessToken, appID, appSecret):
    # Get https://graph.facebook.com/id
    # ?access_token=...
    # Returns dictionary
    pass


def fbGetToken(username, appID, appSecret):
    params = {"client_id": appID,
              "redirect_uri": "http://www.facebook.com/connect/login_success.html",
              "type": "user_agent",
              "display": "wap"
              }

    authPage = fetchURLWithParams("https://graph.facebook.com/oauth/authorize", params)
    matches = re.search(r'''method="post" action="(.*?)".*post_form_id" value="(.*?)".*charset_test" value="(.*?)"''', authPage)
    if matches is None:
        sys.stderr.write("Couldn't parse auth page:\n%s\n" % authPage)
        sys.exit(1)

    postParams = {}
    postURL = re.sub(r'''&amp;''', '&', matches.group(1))
    postParams['email'] = username
    postParams['pass'] = getpass.getpass()
    postParams['post_form_id'] = urllib.unquote(matches.group(2))
    postParams['charset_test'] = matches.group(3)
    postParams['login'] = 'Log In'
    print "Trying %r with %r " % (postURL, postParams)

    authResponse = fetchURLWithParams(postURL, postParams,
                                      post = True)
    matches = re.search(r'''form id="uiserver_form" action="(.*?)"''', authResponse)
    if not matches:
        sys.stderr.write("Couldn't parse authresponse:\n%s\n" % authResponse)
        sys.exit(1)

    postURL = re.sub(r'''&amp;''', '&', matches.group(1))
    postParams = dict(re.findall(r'''input type="hidden" name="(.*?)" value="(.*?)"''', authResponse))
    postParams['grant_clicked'] = 'Allow'
    print "Trying 2: %r with %r " % (postURL, postParams)
    authGrant = fetchURLWithParams(postURL, postParams,
                                   post = True)
    
    print authGrant


def fetchURLWithParams(base, params, post = False):
    if params:
        if post:
            f = urllib2.urlopen(base, urllib.urlencode(params))
        else:
            f = urllib2.urlopen("%s?%s" % (base, urllib.urlencode(params)))
    else:
        f = urllib2.urlopen(base)
    ret = f.read()
    f.close()
    return ret


## Option parsing, etc.


def main(args):
    parser = optparse.OptionParser()
    parser.add_option("-u", "--username", dest="username",
                      help="authenticate as USER", metavar="USER")
    parser.add_option("-f", "--friend", dest="friend",
                      help="look at an album from FRIEND", metavar="FRIEND")
    parser.add_option("-a", "--album", dest="album",
                      help="look at album ALBUM", metavar="ALBUM")
    (options, args) = parser.parse_args(args)

    if len(args) > 0:
        sys.stderr.write("Excess arguments: %r\n" % args)
        sys.exit(1)

    doStuff(username = options.username,
            friend = options.friend,
            album = options.album)


def doStuff(username, friend, album):
    cookiejar = cookielib.LWPCookieJar()
    opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar))
    urllib2.install_opener(opener)


    configFilename = os.path.expanduser("~/.albcomments")
    config = ConfigParser.SafeConfigParser()
    appID = None
    appSecret = None

    appSection = "AppIdentity"
    appIDOption = "appID"
    appSecretOption = "appSecret"
    if os.path.exists(configFilename):
        stat = os.stat(configFilename)
        if stat.st_mode & 2 or stat.st_mode & 020:
            sys.stderr.write("Unsafe permissions on %r.\n" % configFilename)
            sys.exit(1)
        config.read(configFilename)
        if config.has_option(appSection, appIDOption):
            appID = config.get(appSection, appIDOption)
        if config.has_option(appSection, appSecretOption):
            appSecret = config.get(appSection, appSecretOption)
    if appID is None or appSecret is None:
        appID = getpass.getpass("App ID: ")
        appSecret = getpass.getpass("App Secret: ")
        if not config.has_section(appSection):
            config.add_section(appSection)
        config.set(appSection, appIDOption, appID)
        config.set(appSection, appSecretOption, appSecret)
        with open(configFilename, 'wb') as configfile:
            config.write(configfile)
        os.chmod(configFilename, 0600)


    accessToken = None
    if username:
        atSection = "AccessTokens"
        atOption = username

        if config.has_option(atSection, atOption):
            accessToken = config.get(atSection, atOption)

        if accessToken is None:
            accessToken = fbGetToken(username, appID, appSecret)
            if not config.has_section(atSection):
                config.add_section(atSection)
            config.set(atSection, atOption, accessToken)
            with open(configFilename, 'wb') as configfile:
                config.write(configfile)
            os.chmod(configFilename, 0600)


    if friend and album:
        getComments(friend, album, accessToken, appID, appSecret)
    elif album:
        sys.stderr.write("Can't specify album w/o friend!\n")
        sys.exit(1)
    elif friend:
        getAlbums(friend, accessToken, appID, appSecret)
    else:
        getFriends(accessToken, appID, appSecret)


if __name__ == '__main__':
    main(sys.argv[1:])
