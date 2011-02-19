#!/usr/bin/python

import os
import sys
PROJECT_ROOT = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(PROJECT_ROOT, "lib"))


import cgi
import cgitb
import ConfigParser
import Cookie
import httplib2
import oauth2 as oauth
import os.path
import simplejson as json
import time
import twitter

cgitb.enable()

PREFS_PATH = os.path.expanduser("~/.twmi")

config = ConfigParser.SafeConfigParser()
config.read(PREFS_PATH)

consumer_key = config.get('apikey', 'consumer_key')
consumer_secret = config.get('apikey', 'consumer_secret')
request_token_url = config.get('apikey', 'request_token_url')
access_token_url  = config.get('apikey', 'access_token_url')
authorize_url = config.get('apikey', 'authorize_url')

cookie = Cookie.SimpleCookie()
cookie_string = os.environ.get("HTTP_COOKIE")
if cookie_string:
    cookie.load(cookie_string)

##rt_callback_url="http://localhost/backend.py/got_request_token"

def get_request_token():
    consumer = oauth.Consumer(consumer_key, consumer_secret)
    client = oauth.Client(consumer)
    resp, content = client.request(request_token_url, "POST")
    if int(resp['status']) != 200:
        raise "Error getting request token: %r / %r" % (resp, content)

    request_token = dict(cgi.parse_qsl(content))
    cookie["oauth_secret"] = request_token["oauth_token_secret"]


    print "Status: 302 Temporary Moved"
    print "Content-type: text/plain"
    print cookie
    print "Location: %s?oauth_token=%s" % (authorize_url, request_token["oauth_token"])
    print ""
    print "Go to Twitter..."


def get_access_token(oauth_secret, oauth_token, oauth_verifier):
    consumer = oauth.Consumer(consumer_key, consumer_secret)
    token = oauth.Token(oauth_token, oauth_secret)
    token.set_verifier(oauth_verifier)

    client = oauth.Client(consumer, token)
    resp, content = client.request(access_token_url, "POST")
    access_token = dict(cgi.parse_qsl(content))

    cookie["access_token"] = access_token['oauth_token']
    cookie["access_token_secret"] = access_token['oauth_token_secret']
    print "Status: 302 Temporary Moved"
    print "Content-type: text/plain"
    print cookie
    print "Location: http://zevils.com/misc/twmi/"
    print ""
    print "Redirecting..."


def get_friends(api):
    users = api.GetFriends()
    print "Status: 200"
    print "Content-type: text/plain"
    print ""
    for u in users:
        print "%s\n" % u.name


path = os.environ.get("PATH_INFO", "")
oauth_secret = cookie.get("oauth_secret")
access_token = cookie.get("access_token")
access_token_secret = cookie.get("access_token_secret")
if access_token and access_token_secret:
    api = twitter.Api(consumer_key=consumer_key,
                      consumer_secret=consumer_secret,
                      access_token_key=access_token.value,
                      access_token_secret=access_token_secret.value)
    get_friends(api)
elif path == "/verified" and oauth_secret:
    qs = os.environ.get("QUERY_STRING", "")
    query_params = dict(cgi.parse_qsl(qs))
    get_access_token(oauth_secret=oauth_secret.value,
                     oauth_token=query_params.get("oauth_token"),
                     oauth_verifier=query_params.get("oauth_verifier"))
else:
    get_request_token()
