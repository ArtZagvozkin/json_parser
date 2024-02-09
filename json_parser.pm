#!/usr/bin/perl
#Artem Zagvozkin, 07.03.2021, ver 0.1
# https://www.json.org/json-en.html

package json_parser;

use strict;
use utf8;
use POSIX qw(strftime);
use Encode qw(decode encode);

my $input;
my $inp_len;
my $current_pos;
my $current_line;


#################################
########## decode json ##########
sub decode_json {
    ($input) = @_;

    $inp_len = length $input;
    $current_pos = 0;
    $current_line = 1;

    if ($inp_len == 0) {
        print "error 0";
        exit;
    }

    skip_whitespace();

    if (substr($input, $current_pos, 1) eq '{') {
        return read_object();
    }
    elsif (substr($input, $current_pos, 1) eq '[') {
        return read_array();
    }
    else {
        print "expected: '{' or '['\n";
        exit;
    }
}

sub read_array {
    my @result = ();

    $current_pos += 1; #skip '['
    skip_whitespace();
    check_out_of_line();

    #if it's empty array: [ ]
    if (substr($input, $current_pos, 1) eq ']') {
        $current_pos += 1; #skip ']'
        return \@result;
    }

    #read array of values
    while (1==1) {
        #read value and push to array
        push @result, read_value();

        #check ] or ,
        skip_whitespace();
        check_out_of_line();
        if (substr($input, $current_pos, 1) eq ',') {
            $current_pos += 1; #skip ','
        }
        elsif (substr($input, $current_pos, 1) eq ']') {
            $current_pos += 1; #skip ']'
            last;
        }
        else {
            print "expected: ']' or ','\n";
            exit;
        }
    }

    return \@result;
}

sub read_object {
    my %result = ();

    $current_pos += 1; #skip '{'
    skip_whitespace();
    check_out_of_line();

    #if it's empty object: { }
    if (substr($input, $current_pos, 1) eq '}') {
        $current_pos += 1; #skip '}'
        return \%result;
    }

    #read key:value
    while (1==1) {
        skip_whitespace();
        check_out_of_line();

        #read key
        my $key = read_string();

        #check colon ':'
        check_colon();

        #read value and save key:value
        $result{$key} = read_value();

        #check } or ,
        skip_whitespace();
        check_out_of_line();
        if (substr($input, $current_pos, 1) eq ',') {
            $current_pos += 1; #skip ','
        }
        elsif (substr($input, $current_pos, 1) eq '}') {
            $current_pos += 1; #skip '}'
            return \%result;
        }
        else {
            print "expected: '}' or ','\n";
            exit;
        }
    }
}

sub check_colon { #check ':'
    skip_whitespace();
    check_out_of_line();

    if (substr($input, $current_pos, 1) ne ':') {
        print "error: expected ':'\n";
        exit;
    }
    $current_pos += 1;
}

sub read_value {
    my $value;
    skip_whitespace();
    check_out_of_line();

    if (substr($input, $current_pos, 1) eq '"') { #string
        return read_string();
    }
    elsif (substr($input, $current_pos, 1) eq '-' || substr($input, $current_pos, 1) eq '+' ||
           (substr($input, $current_pos, 1) ge '0' && substr($input, $current_pos, 1) le '9')
          ) { #number
        return read_number();
    }
    elsif (substr($input, $current_pos, 1) eq '{') { #object
        return read_object();
    }
    elsif (substr($input, $current_pos, 1) eq '[') { ###array
        return read_array();
    }
    elsif (substr($input, $current_pos, 1) eq 't') { #true
        return read_true();
    }
    elsif (substr($input, $current_pos, 1) eq 'f') { #false
        return read_false();
    }
    elsif (substr($input, $current_pos, 1) eq 'n') { #null
        return read_null();
    }

    print "error: invalid value\n";
    exit;
}

sub read_string {
    my $value = "";

    #check first "
    if (substr($input, $current_pos, 1) ne '"') {
        return print "error 2";
    }

    #skip first "
    $current_pos += 1;

    #wait second "
    while (substr($input, $current_pos, 1) ne '"') {
        check_out_of_line();
        $value .= substr($input, $current_pos, 1);

        if (substr($input, $current_pos, 1) eq '\\') {
            $current_pos += 1;
            $value .= substr($input, $current_pos, 1);
        }
        $current_pos += 1;
    }
    $current_pos += 1; #skip second "

    return "\"$value\"";
}

sub read_number {
    my $value = "";

    #read sign
    if (substr($input, $current_pos, 1) eq '-' || substr($input, $current_pos, 1) eq '+') {
        $value .= substr($input, $current_pos, 1);
        $current_pos += 1;
        check_out_of_line();
    }

    #check digit
    if (substr($input, $current_pos, 1) lt '0' || substr($input, $current_pos, 1) gt '9') {
        print "error: expected digit\n";
        exit;
    }

    #read digits
    while (substr($input, $current_pos, 1) ge '0' && substr($input, $current_pos, 1) le '9') {
        $value .= substr($input, $current_pos, 1);
        $current_pos += 1;
        check_out_of_line();
    }

    #read fraction
    if (substr($input, $current_pos, 1) eq '.') {
        $value .= substr($input, $current_pos, 1);
        $current_pos += 1;
        check_out_of_line();

        #check digit
        if (substr($input, $current_pos, 1) lt '0' || substr($input, $current_pos, 1) gt '9') {
            print "error: expected digit\n";
            exit;
        }

        #read digits
        while (substr($input, $current_pos, 1) ge '0' && substr($input, $current_pos, 1) le '9') {
            $value .= substr($input, $current_pos, 1);
            $current_pos += 1;
            check_out_of_line();
        }
    }

    #read exponent
    if (substr($input, $current_pos, 1) eq 'e' || substr($input, $current_pos, 1) eq 'E') {
        $value .= substr($input, $current_pos, 1);
        $current_pos += 1;
        check_out_of_line();

        #check sign
        if (substr($input, $current_pos, 1) eq '-' || substr($input, $current_pos, 1) eq '+') {
            $value .= substr($input, $current_pos, 1);
            $current_pos += 1;
            check_out_of_line();
        }

        #check digit
        if (substr($input, $current_pos, 1) lt '0' || substr($input, $current_pos, 1) gt '9') {
            print "error: expected digit\n";
            exit;
        }

        #read digits
        while (substr($input, $current_pos, 1) ge '0' && substr($input, $current_pos, 1) le '9') {
            $value .= substr($input, $current_pos, 1);
            $current_pos += 1;
            check_out_of_line();
        }
    }

    return $value*1;
}

sub read_true {
    if ($inp_len - $current_pos < 4) {
        print "error 5";
        exit;
    }

    if (substr($input, $current_pos, 4) ne 'true') {
        print "error 5";
        exit;
    }
    $current_pos += 4;

    return "true";
}

sub read_false {
    if ($inp_len - $current_pos < 5) {
        print "error 5";
        exit;
    }

    if (substr($input, $current_pos, 5) ne 'false') {
        print "error 5";
        exit;
    }
    $current_pos += 5;

    return "false";
}

sub read_null {
    if ($inp_len - $current_pos < 4) {
        print "error 5";
        exit;
    }

    if (substr($input, $current_pos, 4) ne 'null') {
        print "error 5";
        exit;
    }
    $current_pos += 4;

    return "null";
}

sub check_out_of_line {
    if ($current_pos >= $inp_len) {
        print "Error: out of line\n";
        exit;
    }
}

sub skip_whitespace {
    while (substr($input, $current_pos, 1) eq " " ||
           substr($input, $current_pos, 1) eq "\n" ||
           substr($input, $current_pos, 1) eq "\t" ||
           substr($input, $current_pos, 1) eq "\r")
    {
        if (substr($input, $current_pos, 1) eq "\n") {
            $current_line+=1;
        }
        $current_pos+=1;
    }

    return;
}
########## decode json ##########
#################################



#################################
########## encode json ##########
sub encode_json {
    my ($data) = @_;
    my $json_text = "";

    if (ref($data) eq "HASH") {
        my $i = 0;
        my %hash = %$data;
        my $num = keys(%hash);

        #create json text
        $json_text .= "{";
        foreach my $key (keys %hash) {
            my $value = encode_json($hash{$key});
            $key = get_pretty_key($key);

            $i += 1;
            if ($i != $num) {
                $json_text .= $key.":".$value.",";
            }
            else {
                $json_text .= $key.":".$value;
            }
        }
        $json_text .= "}";

        return $json_text;
    }
    elsif (ref($data) eq "ARRAY") {
        my @array = @{$data};

        #create json text
        $json_text .= "[";
        for (my $i = 0; $i <= $#array; $i++) {
            my $value = encode_json($array[$i]);

            if ($i < $#array) {
                $json_text .= $value.",";
            }
            else {
                $json_text .= $value;
            }
        }
        $json_text .= "]";

        return $json_text;
    }
    elsif ($data ne "") {
        return $data;
    }

    return "null";
}

sub get_pretty_key {
    my ($value) = @_;
    my $len_value = length $value;

    if (substr($value, 0, 1) ne '"' && substr($len_value - 1, 0, 1) ne '"') {
        $value = '"'.$value.'"';
    }

    return $value;
}
########## encode json ##########
#################################

