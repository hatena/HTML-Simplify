HTML-Simplify
==============================

Perl module.

## Dependencies

[cpanfile](http://search.cpan.org/~miyagawa/Module-CPANfile-0.9031/lib/cpanfile.pod) is used to manage dependencies.

```
# install dependencies by using cpanm command
cpanm --installdeps .

# you can specify the install base to install dependencies (-L option)
cpanm -L local --installdeps .
```

## Way to run tests

```
# in case that you have installed dependencies into `local` directory
prove -lvr -Ilocal/lib/perl5 t
```
