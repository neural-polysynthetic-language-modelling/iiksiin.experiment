#!/usr/bin/env ducttape

task iiksin
   < python37="/usr/bin/python3.7"
  :: url="git@github.com:neural-polysynthetic-language-modelling/iiksiin.git"
   > autoencoder="autoencoder.py"
   > create_tensors="iiksiin.py"
   > train_tensors="morphnet/char2morph.py"
   # > activate="bin/activate"
   > activate="/opt/python/3.7/venv/pytorch0.4_cuda10.0/bin/activate"
{
	git clone ${url} code
	mv code/* .
	# ${python37} -m venv .
	source ${activate}
	# pip install -r requirements.txt

}


task data
  :: url="git@github.com:dowobeha/JSALT_NPLM_data.git"
   > grn_bible="data/Other/grn/bible/guarani-bible-segmented.txt"
   > bible_dir="data/Other/grn/bible"
{
	git clone ${url} data
}

task create_tensors
   < activate=@iiksin
   < create_tensors=@iiksin
   < grn_bible=@data
   > out
   :: morph_delimiter=">"
{
	source ${activate}
	python3 ${create_tensors} -d "${morph_delimiter}" -i ${grn_bible} -o ${out}
}

task autoencode
  < autoencoder=@iiksin
  < activate=@iiksin
  < in=$out@create_tensors
 :: epochs=200
 :: batch_size=100
 :: num_hidden_layers=3
 :: hidden_layer_size=50
 :: learning_rate="0.01"
 :: cuda_device="3"
  > out
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
  < autoencoder=@iiksin
  < activate=@iiksin
  < in=$out@create_tensors
  < model=$out@autoencode
 :: cuda_device="3"
  > out
{
	source ${activate}
	python3 ${autoencoder} --mode              t2v                  \
	                       --tensor_file       ${in}                \
	                       --model_file        ${model}             \
			       --cuda_device       ${cuda_device}       \
			       --output            ${out}

}



task train_tensors
  < activate=@iiksin
  < train_tensors=@iiksin
  < tensors=$out@morpheme_vectors
  < bible_dir=@data
{

	source ${activate}
	python3 ${train_tensors} -corpus_dir ${bible_dir} -tensor_file ${tensors} -batch_size 320

}


plan {

#     reach train_tensors
#     reach morpheme_vectors
      reach create_tensors
}
