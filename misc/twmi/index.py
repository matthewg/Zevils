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


def get_access_token(oauth_secret):
    pass



if __name__ == "__main__":
    get_request_token()
else:
    path = os.environ.get("PATH_INFO", "")
    print "Status: 200"
    print "Content-type: text/plain"
    print ""
    print "Path: %r" % path
    print "Cookie: %r" % cookie

    oauth_secret = cookie.get("oauth_secret")
    if path == "/verified" and oauth_secret:
        get_access_token(oauth_secret)
    else:
        get_request_token()


"""
print "Request Token:"
print "    - oauth_token        = %s" % request_token['oauth_token']
print "    - oauth_token_secret = %s" % request_token['oauth_token_secret']
print 

# Step 2: Redirect to the provider. Since this is a CLI script we do not 
# redirect. In a web application you would redirect the user to the URL
# below.

print "Go to the following link in your browser:"
print "%s?oauth_token=%s" % (authorize_url, request_token['oauth_token'])
print 

# After the user has granted access to you, the consumer, the provider will
# redirect you to whatever URL you have told them to redirect to. You can 
# usually define this in the oauth_callback argument as well.
accepted = 'n'
while accepted.lower() == 'n':
    accepted = raw_input('Have you authorized me? (y/n) ')
oauth_verifier = raw_input('What is the PIN? ')

# Step 3: Once the consumer has redirected the user back to the oauth_callback
# URL you can request the access token the user has approved. You use the 
# request token to sign this request. After this is done you throw away the
# request token and use the access token returned. You should store this 
# access token somewhere safe, like a database, for future use.
token = oauth.Token(request_token['oauth_token'],
    request_token['oauth_token_secret'])
token.set_verifier(oauth_verifier)
client = oauth.Client(consumer, token)

resp, content = client.request(access_token_url, "POST")
access_token = dict(urlparse.parse_qsl(content))

print "Access Token:"
print "    - oauth_token        = %s" % access_token['oauth_token']
print "    - oauth_token_secret = %s" % access_token['oauth_token_secret']
print
print "You may now access protected resources using the access tokens above." 
print
"""
