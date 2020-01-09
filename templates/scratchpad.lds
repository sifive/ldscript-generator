{% extends "base.lds" %}

{#
 # Set layout options
 #}
{% set text_in_itim = False %}
{% set ramrodata = False %}

{#
 # Override rom mapping to put everything in ram
 #}
{% set rom = ram %}
