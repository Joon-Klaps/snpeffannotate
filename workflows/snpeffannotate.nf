/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { SNPEFF_SNPEFF          } from '../modules/nf-core/snpeff/snpeff/main.nf'
include { SNPEFF_BUILD           } from '../modules/local/snpeff_build.nf'
include { SNPSIFT_EXTRACTFIELDS  } from '../modules/local/snpsift_extractfields.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SNPEFFANNOTATE {

    take:
    ch_samplesheet // channel: [meta, vcf, fasta, gff]
    main:

    ch_versions = Channel.empty()

    build_in = ch_samplesheet.map{meta, vcf, fasta, gff -> [meta, fasta, gff] }
    ch_vcf = ch_samplesheet.map{meta, vcf, fasta, gff -> [meta, vcf]}

    SNPEFF_BUILD(build_in)
    ch_versions = ch_versions.mix(SNPEFF_BUILD.out.versions)

    snpeff_in = SNPEFF_BUILD.out.db
        .join(ch_vcf)
        .multiMap{meta, db, config, vcf ->
            vcf: [meta, vcf]
            db : meta.id
            cache: [meta, db, config]
        }

    SNPEFF_SNPEFF(snpeff_in.vcf, snpeff_in.db, snpeff_in.cache)
    ch_versions = ch_versions.mix(SNPEFF_SNPEFF.out.versions)


    SNPSIFT_EXTRACTFIELDS(SNPEFF_SNPEFF.out.vcf)
    ch_versions = ch_versions.mix(SNPSIFT_EXTRACTFIELDS.out.versions)

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'snpeffannotate_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
