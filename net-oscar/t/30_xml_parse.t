#!/usr/bin/perl

use Test::More tests => 22;
use File::Basename;
use strict;
use lib "./blib/lib";
no warnings;

require_ok("Net::OSCAR");
require_ok("Net::OSCAR::XML");
Net::OSCAR::XML->import('protoparse');

my $oscar = Net::OSCAR->new();
is(Net::OSCAR::XML::load_xml(dirname($0)."/test.xml"), 1, "loading XML test file");

is_deeply([sort keys(%Net::OSCAR::XML::xmlmap)], [sort qw(
		just_byte
		just_word
		just_dword
		just_data
		fixed_value
		fixed_value_data
		length_prefix
		vax_prefix
		repeated_data
		fixed_width_data
		count_len
		basic_tlv
		named_tlv
		complex_data_tlv
		subtyped_tlv
		count_prefix_tlv
		ref_foo
		ref_bar
		ref
		snac
	), "TLV", "subtyped TLV"], "forward name mapping");

is_deeply({%Net::OSCAR::XML::xml_revmap}, {1 => { 2 => "snac" }}, "reverse name mapping");

$Net::OSCAR::XML::PROTOPARSE_DEBUG = 1;

is_deeply(
	[protoparse($oscar, "just_byte")],
	[{len => 1, type => 'num', packlet => 'C', name => 'x'}],
	"byte"
);
is_deeply(
	[protoparse($oscar, "just_word")],
	[{len => 2, type => 'num', packlet => 'n', name => 'x'}],
	"word"
);
is_deeply(
	[protoparse($oscar, "just_dword")],
	[{len => 4, type => 'num', packlet => 'N', name => 'x'}],
	"dword"
);
is_deeply(
	[protoparse($oscar, "just_data")],
	[{type => 'data', name => 'x'}],
	"data"
);

is_deeply(
	[protoparse($oscar, "fixed_value")],
	[{len => 2, type => 'num', packlet => 'n', value => 123}],
	"fixed-value word"
);
is_deeply(
	[protoparse($oscar, "fixed_value_data")],
	[{type => 'data', value => 'foo'}],
	"fixed-value data"
);

is_deeply(
	[protoparse($oscar, "length_prefix")],
	[{prefix_len => 2, type => 'data', prefix_packlet => 'n', prefix => 'length', name => 'x'}],
	"length prefix"
);
is_deeply(
	[protoparse($oscar, "vax_prefix")],
	[{prefix_len => 2, type => 'data', prefix_packlet => 'v', prefix => 'length', name => 'x'}],
	"vax-order length prefix"
);
is_deeply(
	[protoparse($oscar, "repeated_data")],
	[{type => 'num', len => 2, packlet => "n", count => -1, name => 'x'}],
	"repeated data"
);
is_deeply(
	[protoparse($oscar, "fixed_width_data")],
	[{type => 'data', len => 10, name => 'x'}, {type => 'data', name => 'y'}],
	"fixed-width data"
);

is_deeply(
	[protoparse($oscar, "count_len")],
	[{type => 'data', count => -1, len => 1, name => 'foo'}],
	"count length data"
);

is_deeply(
	[protoparse($oscar, "basic_tlv")],
	[{type => 'tlvchain', items => [
		{
			type => 'data',
			num => 1,
			items => [{type => 'num', packlet => 'n', len => 2, name => 'x'}],
		},{
			type => 'data',
			num => 2,
			items => [{type => 'num', packlet => 'n', len => 2, name => 'y'}],
		}
	]}],
	"TLV chain"
);
is_deeply(
	[protoparse($oscar, "named_tlv")],
	[{type => 'tlvchain', items => [
		{
			type => 'data',
			name => 'foo',
			num => 1,
			items => [{type => 'data', name => 'x'}]
		},{
			type => 'data',
			name => 'bar',
			num => 2,
			items => [{type => 'data', name => 'y'}]
		}
	]}],
	"TLV chain, named TLVs"
);
is_deeply(
	[protoparse($oscar, "complex_data_tlv")],
	[{type => 'tlvchain', items => [
		{
			type => 'data',
			num => 1,
			items => [
				{type => 'data', name => 'foo', len => 3},
				{type => 'num', name => 'bar', len => 2, packlet => 'n'},
				{type => 'num', len => 4, packlet => 'N', value => 1793},
				{type => 'num', name => 'baz', len => 1, packlet => 'C'}
			]
		}
	]}],
	"TLV chain, complex data"
);
is_deeply(
	[protoparse($oscar, "subtyped_tlv")],
	[{type => 'tlvchain', subtyped => 1, items => [
		{
			type => 'data',
			name => 'foo',
			num => 1, subtype => 1,
			items => [{type => 'num', packlet => 'n', len => 2, name => 'x'}]
		},{
			type => 'data',
			name => 'bar',
			num => 1, subtype => 2,
			items => [{type => 'num', packlet => 'n', len => 2, name => 'y'}]
		}
	]}],
	"TLV chain, subtyped TLVs"
);
is_deeply(
	[protoparse($oscar, "count_prefix_tlv")],
	[{type => 'tlvchain', prefix => 'count', prefix_packlet => 'n', prefix_len => 2, items => [
		{type => 'data', num => 1, items => [{type => 'data', name => 'x'}]},
		{type => 'data', num => 2, items => [{type => 'data', name => 'y'}]},
	]}],
	"TLV chain, count prefixed"
);


is_deeply(
	[protoparse($oscar, "ref")],
	[
		{type => 'ref', name => "ref_foo", items => []},
		{type => 'ref', name => "ref_bar", items => []}
	],
	"references"
);
