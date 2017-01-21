#!/bin/bash

fecha=$(date +"%d-%m-%y_%T")

#Esto es con la modificación en .bashrc
## export MadGrapgSYS=/home/camilo/MG-Pythia/MG5_aMC_v2_5_1/
## export PATH=$PATH:$MadGrapgSYS/bin

###########################################################################
# 				FLAGS	          		          #
###########################################################################
flagOut=True
flagDebug=False



##############################END FLAGS####################################

function Error {
    echo ""
    echo "usage:" $0 "<path/script> [-Ph=path/output] [-Ne=Nevents] [-d] [-Q=qcut_value] [-Xq=xcut_value] [-mm2l=minim_mass_lepton_pair] [-Run=Run_Times]"
    echo " "
    echo "Nevents: number of events, 10000=default"
    echo "Run_Times: Number of times MG5_aMC is going to be execute"
    echo "Example:" $0 "script.txt -Ph=~/output -Ne=10000 -Q=30 -Xq=50 -mm2l=50 -Run=10 -delp -Pyt -Cl"

    exit 0
}

if [ -z $1 ]; then #Para fijarse que el argumento no esté vacio
    echo "No path to the MadGraph script supplied (1st argument)"
    Error
else
    if [ ! -f $1 ]; then #Si existe el fichero , -w: si tiene permisos de escritura, -x: si tiene permisos de ejecucución
	echo "The path:" $1 "is empty"
	Error
	exit 0
    fi
    PathScript=$1
fi

#mira si en el script hay una carpeta de salida
DefaultOutput=$(sed -e '/output/ !d' $PathScript)
#parte el texto en DefaultOutput por los espacios
arrOUT=(${DefaultOutput// / })

##############################################################################
#                            OPCIONES POR DEFECTO                            #
##############################################################################

Nevents=10000                                   #Numero de eventos por defecto
DefaultOutDir="~/Default_output_MG/$fecha"         #Salida por defecto
qcut=-1
xcut=0.0
flagDelphes=False
flagPythia=False
mmass2lep=0.0                                    #masa invariante minima de dos leptones
Runtimes=1                                      # número de veces que se ejecuta MG5_aMC
flagCluster=False                               # Si va a usar el modo Cluster
$Clsize=60                                      # Tamaño del cluster por defecto

###########################END OPCIONES POR DEFECTO###########################

#Lee las opciones desde linea de comandos

for var in "$@" #Corre sobre todos los argumentos
do
    while IFS='=' read Opc Val; do #separa por = los argumentos
    
	
	if [ "$Opc" = -Ne ]; then
	    if [ -z "$Val" ]; then
		echo "-Ne is empty, using the default Ne=10000"		
	    else
		Nevents=$Val
	    fi
	fi
	
	if [ "$Opc" = -Ph ]; then  
	    if [ -z "$Val" ]; then #mira si el argumento -Ph de la función está vacio
		echo "Ph empty, using default or script path"
		flagOut=True
      	    else
		PathOutput=$Val #Si se dió un output como argumento, este será el usado.
		flagOut=False
	    fi
	fi
	
	# Para hacer el depurado de errores mas sencillo
	if [ "$Opc" = -d ]; then  
	    flagDebug=True
	fi


	if [ "$Opc" = -Q ]; then
            if [ -z "$Val" ]; then #mira si el argumento -Q de la función está vacio                                                                                              
                echo "Q (qcut) is empty, using default value -1"
            else
                qcut=$Val #Si se dió un valor de qcut, este será el usado.                                                                                           
            fi
        fi

	if [ "$Opc" = -Xq ]; then
            if [ -z "$Val" ]; then #mira si el argumento -Q de la función está vacio                                                                                              
                echo "Xq (xqcut) is empty, using default value 0.0"
            else
                xqcut=$Val #Si se dió un valor de qcut, este será el usado.
	    fi
        fi

	
        if [ "$Opc" = -Delp ]; then
	    flagDelphes=True	    
        fi

	if [ "$Opc" = -Pyt ]; then
	    flagPythia=True
        fi


	if [ "$Opc" = -mm2l ]; then
            if [ -z "$Val" ]; then #mira si el argumento -mm2l de la función está vacio
                echo "Pmm2l empty, using default value 0.0"
            else
		mmass2lep=$Val
            fi
        fi

	if [ "$Opc" = -Run ]; then
            if [ -z "$Val" ]; then #mira si el argumento -Run de la función está vacio
		echo "Run empty, using default value 1"
            else
                Runtimes=$Val
            fi
        fi

        if [ "$Opc" = -Cl ]; then
            
            flagClusters=True
        fi

	
	
	
    done <<< "$var"

done #Fin for para OPCIONES

if [ "$flagDebug" = True ]; then
    echo "Lanching in Debugging mode de script" $0
    echo "3"
    sleep 1s
    echo "2"
    sleep 1s
    echo "1"
    sleep 1s
fi


#Establece la salida
if [ "$flagOut" = True ]; then
    DefaultOutput=$(sed -e '/output/ !d' $PathScript) #mira si en el script hay una carpeta de salida
    arrOUT=(${DefaultOutput// / }) #parte el texto en DefaultOutput por los espacios  
    if [ -z "${arrOUT[1]}" ]; then #si no hay una salida en el escript, usa una por defecto
	PathOutput=$DefaultOutdir
	if [ -z "${arrOUT[0]}" ]; then
	    echo "output" $PathOutput >> $PathScript #Pone en la última línea del script el output por defecto
	fi
    else
	PathOutput=${arrOUT[1]} #si hay un output en el script y no se dió uno como argumento, entonces usa el del script  
    fi
fi


if [ "$flagDebug" = True ]; then
    echo "Numero de eventos=" $Nevents
    echo "Path Script:" $PathScript
    echo "Path Output:" $PathOutput
    echo "qcut" $qcut
    echo "xqcut" $xqcut
    sleep 5
fi

#Escribo el path de salida en el script que ejecuta MadGraph 
cat $PathScript | sed '/output/c\output '$PathOutput' ' > $PathScript.tmp 
cp $PathScript.tmp $PathScript
rm $PathScript.tmp 2> /dev/null

#Genero la carpeta que contiene los programas de MadGraph
mg5_aMC $PathScript 

#MODIFICO LA CONFIGURACION PARA QUE NO ABRA EL NAVEGADOR POR DEFECTO y para que use closter
eval "cat $PathOutput/Cards/me5_configuration.txt | sed '/# automatic_html_opening = True/c\automatic_html_opening = False'>> $PathOutput/Cards/me5_configuration.txt.tmp"
eval "mv $PathOutput/Cards/me5_configuration.txt.tmp $PathOutput/Cards/me5_configuration.txt"

if [ "$flagCluster" = True ]; then
    
    eval "cat $PathOutput/Cards/me5_configuration.txt | sed '/# run_mode = 2/c\run_mode = 1'>> $PathOutput/Cards/me5_configuration.txt.tmp"
    eval "mv $PathOutput/Cards/me5_configuration.txt.tmp $PathOutput/Cards/me5_configuration.txt"
    
    eval "cat $PathOutput/Cards/me5_configuration.txt | sed '/# cluster_type = condor/c\cluster_type = pbs'>> $PathOutput/Cards/me5_configuration.txt.tmp"
    eval "mv $PathOutput/Cards/me5_configuration.txt.tmp $PathOutput/Cards/me5_configuration.txt"
    
    eval "cat $PathOutput/Cards/me5_configuration.txt | sed '/# cluster_nb_retry = 1/c\cluster_nb_retry = 2'>> $PathOutput/Cards/me5_configuration.txt.tmp"
    eval "mv $PathOutput/Cards/me5_configuration.txt.tmp $PathOutput/Cards/me5_configuration.txt"

    eval "cat $PathOutput/Cards/me5_configuration.txt | sed '/# cluster_size/c\ cluster_size = $Clsize'>> $PathOutput/Cards/me5_configuration.txt.tmp"
    eval "mv $PathOutput/Cards/me5_configuration.txt.tmp $PathOutput/Cards/me5_configuration.txt"

fi

#MODIFICO LA runcard PARA tener el número de eventos deseado y para hacer un corte en el pt minimo de los leptones cargados

eval "cat $PathOutput/Cards/run_card.dat | sed '/True  = use_syst ! Enable systematics studies/c\  False  = use_syst ! Enable systematics studies'>> $PathOutput/Cards/run_card.dat.tmp"
eval "mv $PathOutput/Cards/run_card.dat.tmp $PathOutput/Cards/run_card.dat"

eval "cat $PathOutput/Cards/run_card.dat | sed '/! Number of unweighted events requested/c\  $Nevents = nevents ! Number of unweighted events requested'>> $PathOutput/Cards/run_card.dat.tmp"
eval "mv $PathOutput/Cards/run_card.dat.tmp $PathOutput/Cards/run_card.dat"

eval "cat $PathOutput/Cards/run_card.dat | sed '/! min invariant mass of l+l- (same flavour) lepton pair/c\ $mmass2lep   = mmll    ! min invariant mass of l+l- (same flavour) lepton pair'>> $PathOutput/Cards/run_card.dat.tmp"
eval "mv $PathOutput/Cards/run_card.dat.tmp $PathOutput/Cards/run_card.dat"

#Modifico el xqcut en run_card.dat
eval "cat $PathOutput/Cards/run_card.dat | sed '/! minimum kt jet measure between partons/c\  $xqcut  = xqcut ! minimum kt jet measure between partons'>> $PathOutput/Cards/run_card.dat.tmp"
eval "mv $PathOutput/Cards/run_card.dat.tmp $PathOutput/Cards/run_card.dat"


if [ "$flagPythia" = True ]; then
#creo (para que ejecute pytia) y  Modifico qcut en la pythia8_card.dat 
eval "cat $PathOutput/Cards/pythia8_card_default.dat | sed '/JetMatching:qCut/c\JetMatching:qCut         = $qcut'>> $PathOutput/Cards/pythia8_card.dat.tmp"
eval "mv $PathOutput/Cards/pythia8_card.dat.tmp $PathOutput/Cards/pythia8_card.dat"
fi

if [ "$flagDelphes" = True ]; then
#Creo la delfestt_card.dat usando la del cms
eval "cp $PathOutput/Cards/delphes_card_CMS.dat $PathOutput/Cards/delphes_card.dat"
fi

execute=$(echo $PathOutput"/bin/generate_events -f")

for i in `seq 1 $Runtimes`;
do
    echo "===================================================================================================="   
    echo "Run"$i
    echo "===================================================================================================="   
    
    #Modifico la run Card con un valor de iseed diferente cada ves que ejecuto
    Iseed=$(echo $(($RANDOM%10))) #número aleatorio entre 0 y 10, para modificar la semilla del montecarlo
    eval "cat $PathOutput/Cards/run_card.dat | sed '/! rnd seed (0=assigned automatically=default))/c\  $Iseed   = iseed   ! rnd seed (0=assigned automatically=default))'>> $PathOutput/Cards/run_card.dat.tmp"
    eval "mv $PathOutput/Cards/run_card.dat.tmp $PathOutput/Cards/run_card.dat"
    
    eval "$execute"

done 

