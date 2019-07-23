#!/usr/bin/env ducttape

global {

}

task iiksiin
   < python37="/usr/bin/python3.7"
  :: url="git@github.com:neural-polysynthetic-language-modelling/iiksiin.git"
   > autoencoder="autoencoder.py"
   > create_tensors="iiksiin.py"
   > train_tensors="morphnet/char2morph.py"
   > activate="bin/activate"
  # > activate="/opt/python/3.7/venv/pytorch0.4_cuda10.0/bin/activate"
{
	git clone ${url} code
	mv code/* .
	${python37} -m venv .
	source ${activate}
	pip install -r requirements.txt

}


task data_repo
   < JSALT_NLPM_data="/home/lanes/JSALT_NPLM_data"
   > data_dir
{
#	git clone ${url} ${data_dir}
#	cd ${data_dir}
#	git annex enableremote kulusiq
#	git annex sync --content
	ln -s ${JSALT_NLPM_data} ${data_dir}
}

task data
   < data_dir=@data_repo
  :: subdir=(Lang: grn=(Condition: mt="Other/grn/grn-spa/preprocess/output/all/fst"
                                  all="Other/grn/grn-spa/preprocess/monolingual/all/fst"
                                   nt="Other/grn/grn-spa/preprocess/monolingual/NT/fst")
	           ess=(Condition: mt="Inuit-Yupik/ess/parallel_corpus/new_testament/preprocess/output/all/fst"
	                          all="Inuit-Yupik/ess/parallel_corpus/new_testament/preprocess/monolingual/all/fst"
                                   nt="Inuit-Yupik/ess/parallel_corpus/new_testament/preprocess/monolingual/NT/fst"))
  :: suffix=(Lang: grn=(Condition: mt="tc.grn"
                                  all="tok.grn"
     				   nt="tok.grn")
                   ess=(Condition: mt="tc.ess"
		                  all="tok.ess"
		  		   nt="tok.ess"))
   > train
   > dev
   > test
   > corpus_dir="."
{
	ln --verbose -s ${data_dir}/${subdir}/train.${suffix} ${train}

	if [[ -f "${data_dir}/${subdir}/dev.${suffix}" ]]; then
		ln --verbose -s ${data_dir}/${subdir}/dev.${suffix}   ${dev}
	elif [[ -f "${data_dir}/${subdir}/valid.${suffix}" ]]; then
                ln --verbose -s ${data_dir}/${subdir}/valid.${suffix}   ${dev}
	else
		echo "Unable to find ${data_dir}/${subdir}/dev.${suffix} or ${data_dir}/${subdir}/valid.${suffix}"
	fi
	
	ln --verbose -s ${data_dir}/${subdir}/test.${suffix}  ${test}
}

task create_tensors
   < activate=@iiksiin
   < create_tensors=@iiksiin
   < in=$train@data
  :: max_characters=20
  :: morph_delimiter=(Lang: grn=">" ess=">")
  :: blacklist_char=(Lang: grn="*" ess="*")
   > out="train.tensors"
{
	source ${activate}
	python3 ${create_tensors} --morpheme_delimiter "${morph_delimiter}" \
	                          --max_characters     "${max_characters}"  \
				  --blacklist_char     "${blacklist_char}"  \
				  --input_file         "${in}"              \
				  --output_file        "${out}"       
}

task autoencode
  < autoencoder=@iiksiin
  < activate=@iiksiin
  < in=$out@create_tensors
 :: epochs=250
 :: batch_size=100
 :: num_hidden_layers=3
 :: hidden_layer_size=(VectorSize: 64 128 256 512)
 :: learning_rate="0.01"
 :: cuda_device="3"
  > out="train.autoencoder.model"
{
	source ${activate}
	python3 ${autoencoder} --mode              train                \
	                       --tensor_file       ${in}                \
	                       --epochs            ${epochs}            \
	                       --batch_size        ${batch_size}        \
			       --hidden_layer_size ${hidden_layer_size} \
			       --hidden_layers     ${num_hidden_layers} \
			       --learning_rate     ${learning_rate}     \
			       --cuda_device       ${cuda_device}       \
			       --output            ${out}
}

task morpheme_vectors
  < autoencoder=@iiksiin
  < activate=@iiksiin
  < in=$out@create_tensors
  < model=$out@autoencode
 :: cuda_device="3"
  > out="train.vectors"
{
	source ${activate}
	python3 ${autoencoder} --mode              t2v                  \
	                       --tensor_file       ${in}                \
	                       --model_file        ${model}             \
			       --cuda_device       ${cuda_device}       \
			       --output            ${out}

}



task train_tensors
  < activate=@iiksiin
  < train_tensors=@iiksiin
  < tensors=$out@morpheme_vectors
  < corpus_dir=@data
{

	source ${activate}
	python3 ${train_tensors} -corpus_dir ${corpus_dir} -tensor_file ${tensors} -batch_size 320

}


plan {

  reach iiksiin
  reach data_repo
  reach data via (Lang: grn) * (Condition: *)
  reach create_tensors via (Lang: grn) * (Condition: *)
  reach autoencode, morpheme_vectors via (Lang: grn) * (Condition: *) * (VectorSize: 512)
#  reach train_tensors
#     reach morpheme_vectors
#      reach create_tensors
}
