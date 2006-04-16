use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME' => 'cybozu2ical',
    'VERSION_FROM' => 'cybozu2ical',
    'PREREQ_PM' => {
        Text::CSV_XS => 0,
        Data::ICal => 0,
        DateTime => 0,
        YAML => 0,
    },
    EXE_FILES => [ 'cybozu2ical' ],
);
