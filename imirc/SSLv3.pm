package SSLv3;

use IO::Socket::SSL;
@ISA = qw(IO::Socket::SSL);

sub context_init {
  my $args = shift;
  my ($ctx);  

  if ( ! defined ($ctx = SSLv3_Context->new($args)) ) {
    return $ctx;  
  }
  $IO::Socket::SSL::SSL_Context_obj = $ctx;

  return 1;
}


package SSLv3_Context;

@ISA = qw(SSL_Context);

sub new {
  my ($class, $args) = @_;

  my ($key_file, $cert_file, $ca_file, $ca_path,
      $is_server, $use_cert, $verify_mode, $r, $s, $ctx);

  my $self = {};
  bless $self, $class;

  # get SSL arguments.
  $is_server = $args->{'SSL_server'} || $args->{'Listen'};
  if ( $is_server ) {
    # creating a server socket.
    $key_file='/dev/null';
#$args->{'SSL_key_file'}||$IO::Socket::SSL::DEFAULT_SERVER_KEY_FILE;
    $cert_file='/dev/null';
#$args->{'SSL_cert_file'}||$IO::Socket::SSL::DEFAULT_SERVER_CERT_FILE;
  } else {
    # creating a client socket.
    $key_file= '/dev/null';
#$args->{'SSL_key_file'}||$IO::Socket::SSL::DEFAULT_CLIENT_KEY_FILE;
    $cert_file= '/dev/null';
#$args->{'SSL_cert_file'}||$IO::Socket::SSL::DEFAULT_CLIENT_CERT_FILE;
  }
  $ca_file = '/dev/null';
# $args->{'SSL_ca_file'} || $IO::Socket::SSL::DEFAULT_CA_FILE;
  $ca_path = '/dev/null';
#$args->{'SSL_ca_path'} || $IO::Socket::SSL::DEFAULT_CA_PATH;
  $verify_mode = 0;
  $use_cert = 0;


  # create SSL context;
  if(! ($ctx = Net::SSLeay::CTX_v3_new()) ) {
    my $err_str = IO::Socket::SSL::_get_SSL_err_str();
    return IO::Socket::SSL::_myerror("CTX_new(): '$err_str'.");
  }

  # set options for the context.
  $r = Net::SSLeay::CTX_set_options($ctx, &Net::SSLeay::OP_ALL() );

  # set SSL certificate load paths.
  #if(!($r = Net::SSLeay::CTX_load_verify_locations($ctx,
#						   $ca_file,
#						   $ca_path))) {
#    my $err_str = IO::Socket::SSL::_get_SSL_err_str();
#    return IO::Socket::SSL::_myerror("CTX_load_verify_locations: " .
#				     "'$err_str'.");
#  }

  # NOTE: private key, certificate and certificate verification
  #       mode are associated only to the SSL context. this is
  #       because they are client/server specific attributes and
  #       it doesn't seem to make much sense to change them between
  #       requests (aspa@hip.fi).

  # load certificate and private key.
  if( $is_server || $use_cert ) {
    if(!($r=Net::SSLeay::CTX_use_RSAPrivateKey_file($ctx,
		 $key_file, &Net::SSLeay::FILETYPE_PEM() ))) {
      my $err_str = IO::Socket::SSL::_get_SSL_err_str();    
      return IO::Socket::SSL::_myerror("CTX_use_RSAPrivateKey_file:" .
				       " '$err_str'.");
    }
    if(!($r=Net::SSLeay::CTX_use_certificate_file($ctx,
		 $cert_file, &Net::SSLeay::FILETYPE_PEM() ))) {
      my $err_str = IO::Socket::SSL::_get_SSL_err_str();    
      return IO::Socket::SSL::_myerror("CTX_use_certificate_file:" .
				       " '$err_str'.");
    }
  }

  $r = Net::SSLeay::CTX_set_verify($ctx, $verify_mode, 0);

  $self->{'_SSL_context'} = $ctx;

  return $self;
}
