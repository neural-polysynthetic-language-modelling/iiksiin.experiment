#!/usr/bin/env ducttape

global {
       JSALT_NPLM_data="/home/lanes/JSALT_NPLM_data"
       python37="/usr/bin/python3.7"
}

task fst
  :: url="git@github.com:SaintLawrenceIslandYupik/finite_state_morphology.git"
   > analyzer="fst/lexicon/lexicon.py"
   > extract_splits="fst/lexicon/extract-split-words.py"
   > extract_analyses="fst/lexicon/extract-analyzed-words.py"
   > lexc="fst/ess.lexc"
   > s2u="fst/ess.fomabin"
   > i2u="fst/ess.underlying.fomabin"
{
	git clone --depth 1 --single-branch --branch jsalt2019 ${url} fst
	cd fst
	make ess.fomabin ess.underlying.fomabin
}

task venv
   < python37="/usr/bin/python3.7"
  :: url="git@github.com:neural-polysynthetic-language-modelling/iiksiin.git"
   > activate="bin/activate"
{
	git clone --depth 1 --single-branch --branch master ${url} code
	mv code/requirements.txt .
	${python37} -m venv .
	source ${activate}
	pip install -r requirements.txt
}


task iiksiin
   < python37="/usr/bin/python3.7"
   < activate=@venv
  :: url="git@github.com:neural-polysynthetic-language-modelling/iiksiin.git"
   > create_alphabet="code/alphabet.py"
   > autoencoder="code/autoencoder.py"
   > create_tensors="code/corpus2tensors.py"
   > validate_tensors="code/validate_tensors.py"
   > char2morph="code/char2morph.py"
{
	git clone --depth 1 --single-branch --branch master ${url} code
}


task europarl_tools
  :: url="git@github.com:dowobeha/europarl_tools.git"
   > tokenizer="tools/tools/tokenizer.perl"
   > split_sentences="tools/tools/split-sentences.perl"
{
	git clone --depth 1 --single-branch --branch master ${url} tools
}


task data
  :: data=$JSALT_NPLM_data
  :: lang=(Lang: ess)
  :: condition=(Condition: all nt)
   > train
   > dev
   > test
{

	if [[ "${lang}" == "ess" ]]; then

	   find ${data}/Inuit-Yupik/ess/monolingual_corpus/new_testament/new.testament.ess/ -maxdepth 1 -type f | sort | grep 'B03_.*_Luke' | xargs cat | sed 's,^[[:digit:]]\+[[:space:]]\+,,' | grep -v '^ *$' > ${dev}

	   find ${data}/Inuit-Yupik/ess/monolingual_corpus/new_testament/new.testament.ess/ -maxdepth 1 -type f | sort | grep 'B04_.*_John' | xargs cat | sed 's,^[[:digit:]]\+[[:space:]]\+,,' | grep -v '^ *$' > ${test}

	   if [[ "${condition}" == "nt" || "${condition}" == "all" ]]; then

	      find ${data}/Inuit-Yupik/ess/monolingual_corpus/new_testament/new.testament.ess/ -maxdepth 1 -type f | sort | grep -v 'B03_.*_Luke' | grep -v 'B04_.*_John' | xargs cat | sed 's,^[[:digit:]]\+[[:space:]]\+,,' | grep -v '^ *$' > ${train}

	   fi

	   if [[ "${condition}" == "all" ]]; then
	   
	     for dir in elementary_primers/level1.kallagneghet-drumbeats    \
	                elementary_primers/level2.akiingqwaghneghet-echoes  \
			elementary_primers/level3.suluwet-whisperings nagai \
			sivuqam_nangaghnegha/sivuqam_volume1                \
			sivuqam_nangaghnegha/sivuqam_volume2                \
			sivuqam_nangaghnegha/sivuqam_volume3                \
			ungipaghaghlanga; do

		cat ${data}/Inuit-Yupik/ess/monolingual_corpus/${dir}/*.gold.ess/*.ess.txt >> ${train}	     

	     done

	   fi

	fi
}


task split_sentences
   < script=$split_sentences@europarl_tools
   < raw_train=$train@data
   < raw_dev=$dev@data
   < raw_test=$test@data
  :: lang=(Lang: ess)
   > train
   > dev
   > test
{
	${script} -l ${lang} < ${raw_train} | grep -v '<P>' > ${train}
	${script} -l ${lang} < ${raw_dev}   | grep -v '<P>' > ${dev}
	${script} -l ${lang} < ${raw_test}  | grep -v '<P>' > ${test}
}

task tokenize
   < script=$tokenizer@europarl_tools
   < train_in=$train@split_sentences
   < dev_in=$dev@split_sentences
   < test_in=$test@split_sentences
  :: lang=(Lang: ess)
   > train
   > dev
   > test
{
	${script} -l ${lang} < ${train_in} > ${train}
	${script} -l ${lang} < ${dev_in}   > ${dev}
	${script} -l ${lang} < ${test_in}  > ${test}
}


task analyze
  < python37=@
  < analyzer=@fst
  < in=(Split: train=@tokenize dev=@tokenize test=@tokenize)
  < s2u=@fst
  < i2u=@fst
  < lexc=@fst
  > out
{
	${python37} ${analyzer} --mode   t2a     \
	                        --corpus ${in}   \
				--lexc   ${lexc} \
				--s2u    ${s2u}  \
				--i2u    ${i2u}  \
				--output ${out}
}

task split_words
   < python37=@
   < extract_splits=@fst
   < in=$out@analyze
   > out
{
	${python37} ${extract_splits} < ${in} > ${out}
}

#task data_repo
#   < JSALT_NLPM_data=@
#   > data_dir
#{
#	git clone ${url} ${data_dir}
#	cd ${data_dir}
#	git annex enableremote kulusiq
#	git annex sync --content
#	ln -s ${JSALT_NLPM_data} ${data_dir}
#}

#task data
#   < data_dir=@data_repo
#  :: subdir=(Lang: grn=(Condition: mt="Other/grn/grn-spa/preprocess/output/all/fst"
#                                  all="Other/grn/grn-spa/preprocess/monolingual/all/fst"
#                                   nt="Other/grn/grn-spa/preprocess/monolingual/NT/fst")
#	           ess=(Condition: mt="Inuit-Yupik/ess/parallel_corpus/new_testament/preprocess/output/all/fst"
#	                          all="Inuit-Yupik/ess/parallel_corpus/new_testament/preprocess/monolingual/all/fst"
#                                   nt="Inuit-Yupik/ess/parallel_corpus/new_testament/preprocess/monolingual/NT/fst"))
#  :: suffix=(Lang: grn=(Condition: mt="tc.grn"
#                                  all="tok.grn"
#     				   nt="tok.grn")
#                   ess=(Condition: mt="tc.ess"
#		                  all="tok.ess"
#		  		   nt="tok.ess"))
#   > train
#   > dev
#   > test
#   > corpus_dir="."
#{
#	ln --verbose -s ${data_dir}/${subdir}/train.${suffix} ${train}
#
#	if [[ -f "${data_dir}/${subdir}/dev.${suffix}" ]]; then
#		ln --verbose -s ${data_dir}/${subdir}/dev.${suffix}   ${dev}
#	elif [[ -f "${data_dir}/${subdir}/valid.${suffix}" ]]; then
#                ln --verbose -s ${data_dir}/${subdir}/valid.${suffix}   ${dev}
#	else
#		echo "Unable to find ${data_dir}/${subdir}/dev.${suffix} or ${data_dir}/${subdir}/valid.${suffix}"
#	fi
#	
#	ln --verbose -s ${data_dir}/${subdir}/test.${suffix}  ${test}
#}


task alphabet
   < activate=@venv
   < create_alphabet=@iiksiin
   < in=$out@split_words[Split:train]
  :: lang=(Lang: ess)
  :: morph_delimiter=(Lang: ess="^")
  :: blacklist_char=(Lang: ess="*")
   > out
   > log
{
	source ${activate}
	python3 ${create_alphabet} --description            "${lang}"            \
	                           --morpheme_delimiter     "${morph_delimiter}" \
				   --end_of_morpheme_symbol '\u0000'             \
				   --input_file             "${in}"              \
				   --blacklist_char         "${blacklist_char}"  \
				   --output_file            "${out}"             \
				   --log                    "${log}"
}

plan {

#     reach fst
#     reach iiksiin
#     reach tokenize via (Lang: ess) * (Condition: all nt)
     reach split_words via (Lang: ess) * (Condition: all) * (Split: train dev)

     reach alphabet via (Lang: ess) * (Condition: all)

     reach create_tensors via (Lang: ess) * (Condition: all) * (Split: train)
#    reach validate_tensors via (Lang: ess) * (Condition: all) * (Split: train)
     
#     reach autoencode via (Lang: ess) * (Condition: all) * (Split: train) * (VectorSize: 64) * (AutoencoderLayers: 7) * (AutoencoderEpochs: 1000)
#     reach morpheme_vectors via (Lang: ess) * (Condition: all) * (Split: train) * (VectorSize: 64) * (AutoencoderLayers: 7) * (AutoencoderEpochs: 1000)
#     reach validate_vectors via (Lang: ess) * (Condition: all) * (Split: train) * (VectorSize: 128) * (AutoencoderLayers: 7) * (AutoencoderEpochs: 10000)
     reach validate_vectors via (Lang: ess) * (Condition: all) * (Split: train) * (VectorSize: 512) * (AutoencoderLayers: 3) * (AutoencoderEpochs: 1000)     
}


task create_tensors
   < activate=@venv
   < create_tensors=@iiksiin
   < in=$out@split_words
   < alphabet=$out@alphabet
  :: max_characters=20
  :: morph_delimiter=(Lang: ess="^")
  :: blacklist_char=(Lang: ess="*")
   > out="train.tensors"
{
	source ${activate}
	python3 ${create_tensors} --morpheme_delimiter "${morph_delimiter}" \
	                          --max_characters     "${max_characters}"  \
				  --blacklist_char     "${blacklist_char}"  \
				  --alphabet           "${alphabet}"        \
				  --input_file         "${in}"              \
				  --output_file        "${out}"       
}

task validate_tensors
   < activate=@venv
   < validate_tensors=@iiksiin
   < in=$out@create_tensors
   < alphabet=$out@alphabet
  :: max_characters=20
   > out="results.tsv"
{
	source ${activate}
	python3 ${validate_tensors} --max_characters     "${max_characters}"  \
				    --alphabet           "${alphabet}"        \
				    --input_file         "${in}"              \
				    --output_file        "${out}"       
}

task autoencode
  < autoencoder=@iiksiin
  < activate=@venv
  < in=$out@create_tensors
  < alphabet=$out@alphabet
 :: epochs=(AutoencoderEpochs: 50 100 150 200 250 300 350 400 450 500 600 700 800 900 1000 2000 3000 4000 5000 6000 7000 8000 9000 10000)
 :: batch_size=100
 :: num_hidden_layers=(AutoencoderLayers: 1 2 3 4 5 6 7 8 9 10)
 :: hidden_layer_size=(VectorSize: 64 128 256 512)
 :: learning_rate="0.01"
 :: cuda_device="3"
  > out="train.autoencoder.model"
{
	source ${activate}
	python3 ${autoencoder} --mode              train                  \
	                       --tensor_file       "${in}"                \
			       --alphabet          "${alphabet}"          \
	                       --epochs            "${epochs}"            \
	                       --batch_size        "${batch_size}"        \
			       --hidden_layer_size "${hidden_layer_size}" \
			       --hidden_layers     "${num_hidden_layers}" \
			       --learning_rate     "${learning_rate}"     \
			       --cuda_device       "${cuda_device}"       \
			       --output            "${out}"
}

task morpheme_vectors
  < autoencoder=@iiksiin
  < activate=@venv
  < in=$out@create_tensors
  < alphabet=$out@alphabet
  < model=$out@autoencode
 :: cuda_device="3"
  > out="train.vectors"
{
	source ${activate}
	python3 ${autoencoder} --mode              t2v                  \
	                       --tensor_file       "${in}"              \
			       --alphabet          "${alphabet}"        \
	                       --model_file        "${model}"           \
			       --cuda_device       "${cuda_device}"     \
			       --output            "${out}"

}

task validate_vectors
  < autoencoder=@iiksiin
  < activate=@venv
  < alphabet=$out@alphabet
  < tensors=$out@create_tensors
  < vectors=$out@morpheme_vectors
  < model=$out@autoencode
 :: batch_size="100"
 :: cuda_device="3"
  > out
{
	source ${activate}
	python3 ${autoencoder} --mode              v2s                  \
	                       --alphabet          "${alphabet}"        \
	                       --tensor_file       "${tensors}"         \
	                       --vector_file       "${vectors}"         \
	                       --model_file        "${model}"           \
			       --cuda_device       "${cuda_device}"     \
			       --output            "${out}"

}

task char2morph
  < activate=@venv
  < char2morph=@iiksiin
  < vectors=$out@morpheme_vectors
  < train=@data
  < dev=@data
  < test=@data
{

	source ${activate}
	python3 ${char2morph}
                              --train_file        ${train}   \
                              --dev_file          ${dev}     \
                              --test_file         ${test}    \
                              --vector_file       ${vectors} \
                              --alphabet          grn.alphabet                \
                              --lr                0.0001                      \
                              --autoencoder_model grn.trained_model           \
                              --epochs            300                         \
                              --char2morph_model  grn.char2morph_debug.pt

}


#plan {

#  reach iiksiin
#  reach data_repo
#  reach data via (Lang: grn) * (Condition: *)
#  reach create_tensors via (Lang: grn) * (Condition: *)
#  reach autoencode, morpheme_vectors via (Lang: grn) * (Condition: *) * (VectorSize: 512)
#  reach char2morph
#     reach morpheme_vectors
#      reach create_tensors
#}
