#!/usr/bin/perl -w

use v5.012;

use strict;
use warnings;

use Data::Dumper;
use LWP::UserAgent;
use JSON;

use Try::Tiny;

# SETTINGS
our $NUM_PER_REQUEST = 50;
our $JSON_DIR = "as_json";
our $lwp = LWP::UserAgent->new;

# CODE

# We need one argument.
my $blog_name = $ARGV[0];
die "No blog name provided (expected: something.tumblr.com or something.com)" 
    unless defined $blog_name;

# Delete leading 'http(s)?://'.
$blog_name =~ s/^https?:\/\///g;

# Delete trailing '/'s.
$blog_name =~ s/\/$//g;

# Start pulling posts.
my $current_post = 0;
my $posts_processed = 0;
my $total_posts = -1;
while(1) {
    my $response = $lwp->get("http://$blog_name/api/read/json?callback=__callback__&start=$current_post&num=$NUM_PER_REQUEST");

    unless($response->is_success) {
        say STDERR "Could not retrieve posts from $current_post; skipping.";
        say STDERR "Details: " . Dumper($response);
        next;
    }

    my $content = $response->decoded_content;

    # Delete the JSONP part.
    $content =~ s/^__callback__\((.*)\);$/$1/g;

    # Parse as JSON.
    my $json;
    try {
        $json = from_json($content);
    } catch {
        warn "Error '$_' while processing post: <<$content>>";
        continue;
    };
    $total_posts = $json->{'posts-total'};

    my @posts = @{$json->{'posts'}};
    $current_post += scalar(@posts);
    $posts_processed += scalar(@posts);

    # Process posts please.
    foreach my $post (@posts) {
        my $post_id = $post->{'id'};

        die "No post id for post <<" . Dumper($post) . ">>!"
            unless defined $post_id;

        # What if I edit a post? I want the new version to be saved:
        # that's why I don't skip if the file already exists. Ideally,
        # we'd use MD5 to check if the contents had changed, but that
        # would require an MD5/post-id index.

        open(my $postfile, ">:utf8", "$JSON_DIR/$post_id.json")
            or die "Could not open '$JSON_DIR/$post_id.json': $!";

        # utf8: utf-8
        # pretty: readable
        # canonical: sorted
        my $json_content = to_json($post, { utf8 => 1, pretty => 1, canonical => 1 });
        say $postfile $json_content;

        close($postfile);
    }

    # Report on status.
    my $perc = ($posts_processed/$total_posts) * 100;
    say sprintf("Processed $posts_processed posts of $total_posts (%.2f%%)", $perc);

    if($posts_processed >= $total_posts) {
        last;
    }
}

