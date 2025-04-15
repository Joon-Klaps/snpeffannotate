process SNPEFF_BUILD {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::snpeff=5.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/snpeff:5.0--hdfd78af_1' :
        'quay.io/biocontainers/snpeff:5.0--hdfd78af_1' }"

    input:
    tuple val(meta), path(fasta), path(gff)

    output:
    tuple val(meta), path('snpeff_db'), path("*.config"), emit: db
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def extension = gff.getExtension().replace("3", "")
    if (extension == "gtf") {
        format = "gtf22"
    } else {
        format = "gff3"
    }

    def avail_mem = 4
    if (!task.memory) {
        log.info '[snpEff] Available memory not known - defaulting to 4GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = task.memory.giga
    }
    """
    mkdir -p snpeff_db/genomes/
    mkdir -p snpeff_db/${prefix}/

    ln -s ../../$fasta snpeff_db/genomes/${prefix}.fa
    ln -s ../../$gff snpeff_db/${prefix}/genes.$extension

    echo "${prefix}.genome : ${prefix}" > snpeff.config

    snpEff \\
        -Xmx${avail_mem}g \\
        build \\
        -config snpeff.config \\
        -dataDir ./snpeff_db \\
        -${format} \\
        $args \\
        -v \\
        ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snpeff: \$(echo \$(snpEff -version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
