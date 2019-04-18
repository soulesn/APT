
##  #######################        SETUP


# data_type = 'alice'
# data_type = 'stephen'
# data_type = 'roian'
# data_type = 'brit2'

import APT_interface as apt
import h5py
import PoseTools
import os
import time
import glob
import re
import numpy as np
import matplotlib.pyplot as plt
import apt_expts
import os
import ast
import apt_expts
import os
import pickle
import multiResData


data_type = None
lbl_file = None
op_af_graph = None
gt_lbl = None
nviews = None
proj_name = None
trn_flies = None

cache_dir = '/nrs/branson/mayank/apt_cache'
all_models = ['mdn', 'deeplabcut', 'unet', 'leap', 'openpose']

gpu_model = 'GeForceRTX2080Ti'
sdir = '/groups/branson/home/kabram/bransonlab/APT/deepnet/singularity_stuff'
n_splits = 3


common_conf = {}
common_conf['rrange'] = 10
common_conf['trange'] = 5
common_conf['brange'] = 0.1
common_conf['crange'] = 0.1
common_conf['mdn_use_unet_loss'] = True
common_conf['dl_steps'] = 40000
common_conf['decay_steps'] = 20000
common_conf['save_step'] = 5000
common_conf['batch_size'] = 8
common_conf['normalize_img_mean'] = False
common_conf['adjust_contrast'] = False
common_conf['maxckpt'] = 20


def setup(data_type_in,gpu_device):
    global lbl_file, op_af_graph, gt_lbl, data_type, nviews, proj_name, trn_flies
    data_type = data_type_in
    os.environ['CUDA_VISIBLE_DEVICES'] = '{}'.format(gpu_device)

    if data_type == 'alice':
        lbl_file = '/groups/branson/bransonlab/apt/experiments/data/multitarget_bubble_expandedbehavior_20180425_FxdErrs_OptoParams20181126_dlstripped.lbl'
        op_graph = []
        gt_lbl = '/nrs/branson/mayank/apt_cache/multitarget_bubble/multitarget_bubble_expandedbehavior_20180425_allGT_stripped.lbl'
        op_af_graph = '\(0,1\),\(0,2\),\(1,2\),\(2,3\),\(1,4\),\(4,7\),\(3,9\),\(7,5\),\(9,5\),\(5,6\),\(7,8\),\(8,12\),\(9,10\),\(10,15\),\(16,3\),\(11,4\),\(14,5\),\(13,5\)'
        groups = ['']
    elif data_type == 'stephen':
        lbl_file = '/groups/branson/bransonlab/apt/experiments/data/sh_trn4992_gtcomplete_cacheddata_updatedAndPpdbManuallyCopied20190402_dlstripped.lbl'
        gt_lbl = lbl_file
        op_af_graph = '\(0,1\),\(0,2\),\(2,3\),\(1,3\),\(0,4\),\(1,4\)'
        trn_flies = [212, 216, 219, 229, 230, 234, 235, 241, 244, 245, 251, 254, 341, 359, 382, 417, 714, 719]
        trn_flies = trn_flies[::2]

    elif data_type == 'roian':
        lbl_file = '/groups/branson/bransonlab/apt/experiments/data/roian_apt_dlstripped.lbl'
        op_af_graph = '\(0,1\),\(0,2\),\(0,3\),\(1,2\),\(1,3\),\(2,3\)'
    elif data_type == 'brit0':
        lbl_file = '/groups/branson/bransonlab/apt/experiments/data/britton_dlstripped_0.lbl'
        op_af_graph = '\(0,3\),\(1,2\),\(4,3\),\(4,2\),\(0,1\),\(2,3\)'
    elif data_type == 'brit1':
        lbl_file = '/groups/branson/bransonlab/apt/experiments/data/britton_dlstripped_1.lbl'
        op_af_graph = '\(0,1\),\(1,0\)'
    elif data_type == 'brit2':
        lbl_file = '/groups/branson/bransonlab/apt/experiments/data/britton_dlstripped_2.lbl'
        op_af_graph = '\(0,1\),\(0,2\),\(1,2\)'
    elif data_type == 'romain':
        lbl_file = '/groups/branson/bransonlab/apt/experiments/data/romain_dlstripped.lbl'
        op_af_graph = '(0,6),(6,12),(3,9),(9,15),(1,7),(7,13),(4,10),(10,16),(5,11),(11,17),(2,8),(8,14)'
        op_af_graph = op_af_graph.replace('(','\(')
        op_af_graph = op_af_graph.replace(')','\)')
    else:
        lbl_file = ''

    lbl = h5py.File(lbl_file,'r')
    proj_name = apt.read_string(lbl['projname'])
    nviews = int(apt.read_entry(lbl['cfg']['NumViews']))
    lbl.close()

def run_jobs(cmd_name,cur_cmd,redo=False):
    logfile = os.path.join(sdir,'opt_' + cmd_name+ '.log')
    errfile = os.path.join(sdir,'opt_' + cmd_name+ '.err')

    run = False
    if redo:
        run = True
    elif not os.path.exists(errfile):
        run = True
    else:
        ff = open(errfile,'r').read().lower()
        if ff.find('error'):
            run = True
        else:
            run = False

    if run:
        PoseTools.submit_job(cmd_name, cur_cmd, sdir, gpu_model=gpu_model)
    else:
        print('NOT submitting job {}'.format(cmd_name))


def get_tstr(tin):
    if np.isnan(tin):
        return ' -------- '
    else:
        return time.strftime('%m/%d %H:%M',time.localtime(tin))

def check_train_status(cmd_name, cache_dir, run_name='deepnet'):
    scriptfile = os.path.join(sdir,'opt_' + cmd_name+ '.sh')
    errfile = os.path.join(sdir,'opt_' + cmd_name+ '.err')
    if os.path.exists(scriptfile):
        submit_time = os.path.getmtime(scriptfile)
    else:
        submit_time = np.nan
    if os.path.exists(errfile):
        start_time = os.path.getmtime(errfile)
    else:
        start_time = np.nan

    files = glob.glob(os.path.join(cache_dir, "{}-[0-9]*").format(run_name))
    files.sort(key=os.path.getmtime)
    files = [f for f in files if os.path.splitext(f)[1] in ['.index','']]
    if len(files)>0:
        latest = files[-1]
        latest_model_iter = int(re.search('-(\d*)', latest).groups(0)[0])
        latest_time = os.path.getmtime(latest)
    else:
        latest_model_iter = -1
        latest_time = np.nan

    print('Job:{}, submitted:{}, started:{} latest iter:{} at {}'.format(
          cmd_name, get_tstr(submit_time), get_tstr(start_time),latest_model_iter, get_tstr(latest_time)))
    return latest_model_iter


def plot_results(data_in,ylim=None,xlim=None):
    ps = [50, 75, 90, 95]
    k = data_in.keys()[0]
    npts = data_in[k][0][0].shape[1]
    nc = int(np.ceil(np.sqrt(npts+1)))
    nr = int(np.ceil((npts+1)/float(nc)))
    f, ax = plt.subplots(nr, nc, figsize=(10, 10))
    ax = ax.flat
    leg = []
    cc = PoseTools.get_colors(len(data_in))
    for idx,k in enumerate(data_in.keys()):
        mm = []
        mt = []
        for o in data_in[k]:
            dd = np.sqrt(np.sum((o[0] - o[1]) ** 2, axis=-1))
            mm.append(np.percentile(dd, ps, axis=0))
            mt.append(o[-1])
        t0 = mt[0]
        mt = np.array([t - t0 for t in mt]) / 60.
        mm = np.array(mm)

        for ndx in range(npts):
            ax[ndx].plot(mt[1:], mm[1:, :, ndx], color=cc[idx, :])
            if xlim is not None:
                ax[ndx].set_xlim([0, xlim])
            if ylim is not None:
                ax[ndx].set_ylim([0, ylim])
        leg.append('{}'.format(k))
        ax[-1].plot([0, 1], [0, 1], color=cc[idx, :])
    ax[-1].legend(leg)


def save_mat(out_exp,out_file):
    import hdf5storage
    out_arr = {}
    for k in out_exp.keys():
        cur = out_exp[k]
        all_dd = []
        for c in cur:
            dd = {}
            dd[u'pred'] = c[0]
            dd[u'labels'] = c[1]
            dd[u'model_file'] = c[3]
            dd[u'model_timestamp'] = c[5]
            iter = int(re.search('-(\d*)', c[3]).groups(0)[0])
            dd[u'model_iter'] = iter

            all_dd.append(dd)
        out_arr[unicode(k)] = all_dd
    hdf5storage.savemat(out_file,out_arr,truncate_existing=True)


def run_trainining(exp_name,train_type,view,run_type):

    common_cmd = 'APT_interface.py {} -name {} -cache {}'.format(lbl_file, exp_name, cache_dir)
    end_cmd = 'train -skip_db -use_cache'
    cmd_opts = {}
    cmd_opts['type'] = train_type
    cmd_opts['view'] = view + 1
    conf_opts = common_conf.copy()
    # conf_opts.update(other_conf[conf_id])
    conf_opts['save_step'] = conf_opts['dl_steps'] / 10
    if data_type in ['brit0' ,'brit1']:
        if train_type == 'unet':
            conf_opts['batch_size'] = 2
        else:
            conf_opts['batch_size'] = 4
    if op_af_graph is not None:
        conf_opts['op_affinity_graph'] = op_af_graph

    if len(conf_opts) > 0:
        conf_str = ' -conf_params'
        for k in conf_opts.keys():
            conf_str = '{} {} {} '.format(conf_str, k, conf_opts[k])
    else:
        conf_str = ''

    opt_str = ''
    for k in cmd_opts.keys():
        opt_str = '{} -{} {} '.format(opt_str, k, cmd_opts[k])

    cur_cmd = common_cmd + conf_str + opt_str + end_cmd
    cmd_name = '{}_view{}_{}_{}'.format(data_type, view, exp_name, train_type)
    if run_type == 'submit':
        print cur_cmd
        print
        run_jobs(cmd_name, cur_cmd)
    elif run_type == 'status':
        conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
        check_train_status(cmd_name, conf.cachedir)



def create_normal_dbs():
    exp_name = 'apt_expt'
    assert gt_lbl is not None
    for view in range(nviews):
        for tndx in range(len(all_models)):
            train_type = all_models[tndx]
            conf = apt.create_conf(lbl_file,view,exp_name,cache_dir,train_type)
            if train_type == 'deeplabcut':
                apt.create_deepcut_db(conf,split=False,use_cache=True)
            elif train_type == 'leap':
                apt.create_leap_db(conf,split=False,use_cache=True)
            else:
                apt.create_tfrecord(conf,split=False,use_cache=True)


## normal dbs - CV

def create_cv_dbs():
    exp_name = 'apt_expt'
    assert gt_lbl is None
    common_conf = apt.create_conf(lbl_file, 0, exp_name, cache_dir, 'mdn')
    assert not os.path.exists(os.path.join(common_conf.cachedir, 'cv_split_fold_0.json'))
    alltrain, splits, split_files = apt.create_cv_split_files(common_conf, n_splits)
    for view in range(nviews):
        for tndx in range(len(all_models)):
            train_type = all_models[tndx]
            for split in range(n_splits):
                cur_split_file = os.path.join(common_conf.cachedir, 'cv_split_fold_{}.json'.format(split))
                conf = apt.create_conf(lbl_file, view, 'cv_split_{}'.format(split), cache_dir, train_type)
                conf.splitType = 'predefined'
                if train_type == 'deeplabcut':
                    apt.create_deepcut_db(conf,split=True,use_cache=True,split_file=cur_split_file)
                elif train_type == 'leap':
                    apt.create_leap_db(conf,split=True,use_cache=True,split_file=cur_split_file)
                else:
                    apt.create_tfrecord(conf,split=True,use_cache=True,split_file=cur_split_file)


## create incremental dbs

# assert False,'Are you sure?'

def create_incremental_dbs():
    import json
    import os
    exp_name = 'db_sz'
    lbl = h5py.File(lbl_file,'r')
    m_ndx = apt.to_py(lbl['preProcData_MD_mov'].value[0, :].astype('int'))
    t_ndx = apt.to_py(lbl['preProcData_MD_iTgt'].value[0, :].astype('int'))
    f_ndx = apt.to_py(lbl['preProcData_MD_frm'].value[0, :].astype('int'))

    n_mov = lbl['movieFilesAll'].shape[1]

    n_labels = m_ndx.shape[0]
    n_rounds = 8
    n_min = 5
    n_samples = np.logspace(np.log10(n_min),np.log10(n_labels),n_rounds).round().astype('int')

    rand_ndx = np.random.permutation(n_labels)
    lbl.close()
    for ndx, cur_s in enumerate(n_samples):
        cur = rand_ndx[:cur_s]
        splits = [[], []]
        for ex in range(n_labels):
            cur_m = m_ndx[ex]
            cur_t = t_ndx[ex]
            cur_f = f_ndx[ex]
            cur_info = [cur_m,cur_f, cur_t]
            if ex in cur:
                splits[0].append(cur_info)
            else:
                splits[1].append(cur_info)

        exp_name = '{}_randsplit_round_{}'.format(data_type,ndx)
        for view in range(nviews):
            for tndx in range(len(all_models)):
                train_type = all_models[tndx]
                conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
                split_file= os.path.join(conf.cachedir,'splitinfo.json')
                with open(split_file,'w') as f:
                    json.dump(splits,f)

                conf.splitType = 'predefined'
                if train_type == 'deeplabcut':
                    apt.create_deepcut_db(conf, split=True, split_file=split_file,use_cache=True)
                elif train_type == 'leap':
                    apt.create_leap_db(conf, split=True, split_file=split_file, use_cache=True)
                else:
                    apt.create_tfrecord(conf, split=True, split_file=split_file, use_cache=True)


## create invidual animals dbs

def create_individual_animal_db_alice():
    import multiResData
    import random
    import json

    assert data_type == 'alice'
    fly1 = [0,3]
    fly2 = [2,8]
    view = 0
    train_type = 'mdn'
    exp_name = 'single_vs_many'
    n_train = 13 # fly1 and fly2 26 labeled examples
    conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
    gt_db = '/nrs/branson/mayank/apt_cache/multitarget_bubble/gtdata/gtdata_view0.tfrecords'

    split_file1 = os.path.join(cache_dir,proj_name,'single_multiple_fly1.json')
    split_file2 = os.path.join(cache_dir,proj_name,'single_multiple_fly2.json')
    split_fileo = os.path.join(cache_dir,proj_name,'single_multiple_other.json')

    assert not os.path.exists(split_file1)

    ims,locs,info = multiResData.read_and_decode_without_session(gt_db,17,())
    id1 = []; id2 = []; ido = []
    for ndx in range(len(info)):
        if info[ndx][0] == fly1[0] and info[ndx][2] == fly1[1]:
            id1.append(ndx)
        elif info[ndx][0] == fly2[0] and info[ndx][2] == fly2[1]:
            id2.append(ndx)
        else:
            ido.append(ndx)

    random.shuffle(ido)
    random.shuffle(id1)
    random.shuffle(id2)
    ido_train = ido[:n_train]
    ido_test = ido[n_train:]
    id1_train = id1[:n_train]
    id1_test = id1[n_train:]
    id2_train = id2[:n_train]
    id2_test = id2[n_train:]

    split1 = [[],[]] # train on random half of fly 1
    split2 = [[],[]] # train of random half of fly 2
    split3 = [[],[]] # train on random flies other than fly1 and fly2

    for ndx in range(len(info)):
        if ndx in id1_train:
            split1[0].append(info[ndx])
        else:
            split1[1].append(info[ndx])
        if ndx in id2_train:
            split2[0].append(info[ndx])
        else:
            split2[1].append(info[ndx])
        if ndx in ido_train:
            split3[0].append(info[ndx])
        else:
            split3[1].append(info[ndx])


    with open(split_file1,'w') as f:
        json.dump(split1,f)
    with open(split_file2,'w') as f:
        json.dump(split2,f)
    with open(split_fileo,'w') as f:
        json.dump(split3,f)


    exp_name = 'single_vs_many_fly1'
    conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
    conf.splitType = 'predefined'
    envs = multiResData.create_envs(conf, split=True)
    out_fns = [lambda data: envs[0].write(apt.tf_serialize(data)),
               lambda data: envs[1].write(apt.tf_serialize(data))]
    out_splits1 = apt.db_from_lbl(conf, out_fns, True, split_file1, on_gt=True)
    with open(os.path.join(conf.cachedir, 'splitdata.json'), 'w') as f:
        json.dump(out_splits1, f)
    envs[0].close()
    envs[1].close()

    exp_name = 'single_vs_many_fly2'
    conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
    conf.splitType = 'predefined'

    envs = multiResData.create_envs(conf, split=True)
    out_fns = [lambda data: envs[0].write(apt.tf_serialize(data)),
               lambda data: envs[1].write(apt.tf_serialize(data))]
    out_splits2 = apt.db_from_lbl(conf, out_fns, True, split_file2, on_gt=True)
    with open(os.path.join(conf.cachedir, 'splitdata.json'), 'w') as f:
        json.dump(out_splits2, f)
    envs[0].close()
    envs[1].close()

    exp_name = 'single_vs_many_other'
    conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
    conf.splitType = 'predefined'
    envs = multiResData.create_envs(conf, split=True)
    out_fns = [lambda data: envs[0].write(apt.tf_serialize(data)),
               lambda data: envs[1].write(apt.tf_serialize(data))]
    out_splits3 = apt.db_from_lbl(conf, out_fns, True, split_fileo, on_gt=True)
    with open(os.path.join(conf.cachedir, 'splitdata.json'), 'w') as f:
        json.dump(out_splits3, f)
    envs[0].close()
    envs[1].close()


def create_run_individual_animal_dbs_stephen(run_type='status'):

    info_file = '/groups/branson/home/bransonk/tracking/code/APT/SHTrainGTInfo20190416.mat'
    import multiResData
    import random
    import json

    data_info = h5py.File(info_file,'r')
    assert data_type == 'stephen'
    assert trn_flies is not None
    train_type = 'mdn'
    n_sel = 50

    conf = apt.create_conf(lbl_file,0,'dummy',cache_dir,train_type)
    lbl_movies, _ = multiResData.find_local_dirs(conf)
    in_movies = [PoseTools.read_h5_str(data_info[k]) for k in data_info['trnmovies'][0,:]]
    assert lbl_movies == in_movies

    fly_ids = data_info['trnmidx2flyid'].value.astype('int')
    label_info = get_label_info(conf)

    for cur_fly in trn_flies:
        cur_fly_movies = [ix for ix,j in enumerate(fly_ids[0,:]) if j==cur_fly]
        fly_train_info = [j for j in label_info if j[0] in cur_fly_movies]
        assert len(fly_train_info) > 50
        sel_train = random.sample(fly_train_info,n_sel)
        sel_val = list(set(label_info)-set(sel_train))
        assert len(label_info) == len(sel_train) + len(sel_val)

        cur_split = [sel_train,sel_val]
        exp_name = 'train_fly_{}'.format(cur_fly)
        cur_split_file = os.path.join(cache_dir,proj_name,exp_name) + '.json'
        assert not os.path.exists(cur_split_file)
        with open(cur_split_file,'w') as f:
            json.dump(cur_split,f)

        # create the dbs
        for view in range(nviews):
            conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
            conf.splitType = 'predefined'
            apt.create_tfrecord(conf, split=True, split_file=cur_split_file, use_cache=True)
            run_trainining(exp_name,train_type,view,run_type)

    # one experiment with random labels
    sel_train = random.sample(label_info,n_sel)
    sel_val = list(set(label_info)-set(sel_train))
    assert len(label_info) == len(sel_train) + len(sel_val)

    cur_split = [sel_train,sel_val]
    exp_name = 'train_fly_random'
    cur_split_file = os.path.join(cache_dir,proj_name,exp_name)
    assert not os.path.exists(cur_split_file)
    with open(cur_split_file,'w') as f:
        json.dump(cur_split,f)

    # create the dbs
    for view in range(nviews):
        conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
        conf.splitType = 'predefined'
        apt.create_tfrecord(conf, split=True, split_file=cur_split_file, use_cache=True)
        run_trainining(exp_name,train_type,view,run_type)




def run_normal_training(run_type = 'status'):

    common_conf['dl_steps'] = 100000

    for view in range(nviews):

        for train_type in all_models:

            exp_name = 'apt_expt'
            common_cmd = 'APT_interface.py {} -name {} -cache {}'.format(lbl_file,exp_name, cache_dir)
            end_cmd = 'train -skip_db -use_cache'
            cmd_opts = {}
            cmd_opts['type'] = train_type
            cmd_opts['view'] = view + 1
            conf_opts = common_conf.copy()
            # conf_opts.update(other_conf[conf_id])
            conf_opts['save_step'] = conf_opts['dl_steps']/10
            if data_type == 'stephen':
                conf_opts['batch_size'] = 4
            if op_af_graph is not None:
                conf_opts['op_affinity_graph'] = op_af_graph

            if len(conf_opts) > 0:
                conf_str = ' -conf_params'
                for k in conf_opts.keys():
                    conf_str = '{} {} {} '.format(conf_str,k,conf_opts[k])
            else:
                conf_str = ''

            opt_str = ''
            for k in cmd_opts.keys():
                opt_str = '{} -{} {} '.format(opt_str,k,cmd_opts[k])

            cur_cmd = common_cmd + conf_str + opt_str + end_cmd
            cmd_name = '{}_view{}_{}_{}'.format(data_type,view,exp_name, train_type)
            if run_type == 'submit':
                print cur_cmd
                print
                run_jobs(cmd_name,cur_cmd)
            elif run_type == 'status':
                conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
                check_train_status(cmd_name,conf.cachedir)


## CV Training ---- TRAINING ----

def run_cv_training(run_type='status'):

    common_conf = {}
    common_conf['dl_steps'] = 40000

    assert gt_lbl is None
    for view in range(nviews):
        for tndx in range(len(all_models)):
            train_type = all_models[tndx]
            for split in range(n_splits):
                exp_name = 'cv_split_{}'.format(split)
                common_cmd = 'APT_interface.py {} -name {} -cache {}'.format(lbl_file, exp_name, cache_dir)
                end_cmd = 'train -skip_db -use_cache'
                cmd_opts = {}
                cmd_opts['type'] = train_type
                cmd_opts['view'] = view + 1
                conf_opts = common_conf.copy()
                # conf_opts.update(other_conf[conf_id])
                conf_opts['save_step'] = conf_opts['dl_steps'] / 10
                if data_type in ['brit0' ,'brit1']:
                    if train_type == 'unet':
                        conf_opts['batch_size'] = 2
                    else:
                        conf_opts['batch_size'] = 4
                if data_type in ['romain']:
                    if train_type in ['mdn']:
                        conf_opts['batch_size'] = 2
                    elif train_type in ['unet']:
                        conf_opts['batch_size'] = 1
                    else:
                        conf_opts['batch_size'] = 4
                if op_af_graph is not None:
                    conf_opts['op_affinity_graph'] = op_af_graph

                if len(conf_opts) > 0:
                    conf_str = ' -conf_params'
                    for k in conf_opts.keys():
                        conf_str = '{} {} {} '.format(conf_str, k, conf_opts[k])
                else:
                    conf_str = ''

                opt_str = ''
                for k in cmd_opts.keys():
                    opt_str = '{} -{} {} '.format(opt_str, k, cmd_opts[k])

                cur_cmd = common_cmd + conf_str + opt_str + end_cmd
                cmd_name = '{}_view{}_{}_{}'.format(data_type, view, exp_name, train_type)
                if run_type == 'submit':
                    print cur_cmd
                    print
                    run_jobs(cmd_name, cur_cmd)
                elif run_type == 'status':
                    conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
                    check_train_status(cmd_name, conf.cachedir)


## DLC augment vs no augment ---- TRAINING ----

# assert False,'Are you sure?'

def run_dlc_augment_training(run_type = 'status'):
    # run_type = 'submit'; redo = False
    # gpu_model = 'TeslaV100_SXM2_32GB'
    train_type = 'deeplabcut'
    common_conf['dl_steps'] = 100000

    other_conf = [{'dlc_augment':True},{'dlc_augment':False,'dl_steps':300000}]
    cmd_str = ['dlc_aug','dlc_noaug']
    cache_dir = '/nrs/branson/mayank/apt_cache'
    exp_name = 'apt_expt'

    for view in range(nviews):

        for conf_id in range(len(other_conf)):

            common_cmd = 'APT_interface.py {} -name apt_expt -cache {}'.format(lbl_file,cache_dir)
            end_cmd = 'train -skip_db -use_cache'
            cmd_opts = {}
            cmd_opts['type'] = train_type
            cmd_opts['train_name'] = cmd_str[conf_id]
            cmd_opts['view'] = view + 1
            conf_opts = common_conf.copy()
            conf_opts.update(other_conf[conf_id])
            conf_opts['save_step'] = conf_opts['dl_steps']/20
            if data_type == 'stephen':
                conf_opts['batch_size'] = 4

            if len(conf_opts) > 0:
                conf_str = ' -conf_params'
                for k in conf_opts.keys():
                    conf_str = '{} {} {} '.format(conf_str,k,conf_opts[k])
            else:
                conf_str = ''

            opt_str = ''
            for k in cmd_opts.keys():
                opt_str = '{} -{} {} '.format(opt_str,k,cmd_opts[k])

            cur_cmd = common_cmd + conf_str + opt_str + end_cmd

            cmd_name = '{}_view{}_{}'.format(data_type,view,cmd_str[conf_id])
            if run_type == 'submit':
                print cur_cmd
                print
                run_jobs(cmd_name,cur_cmd)
            elif run_type == 'status':
                conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
                check_train_status(cmd_name,conf.cachedir,cmd_str[conf_id])


def run_incremental_training(run_type='status'):
    # Expt where we find out how training error changes with amount of training data

    n_rounds = 8
    info = []
    for view in range(nviews):
        r_info = []
        for ndx in range(n_rounds):
            exp_name = '{}_randsplit_round_{}'.format(data_type,ndx)
            cur_info = {}
            for train_type in all_models:

                common_cmd = 'APT_interface.py {} -name {} -cache {}'.format(lbl_file,exp_name, cache_dir)
                end_cmd = 'train -skip_db -use_cache'
                cmd_opts = {}
                cmd_opts['type'] = train_type
                cmd_opts['view'] = view + 1
                conf_opts = common_conf.copy()
                # conf_opts.update(other_conf[conf_id])
                conf_opts['save_step'] = conf_opts['dl_steps']/ 10
                if data_type == 'stephen':
                    conf_opts['batch_size'] = 4
                if op_af_graph is not None:
                    conf_opts['op_affinity_graph'] = op_af_graph

                if len(conf_opts) > 0:
                    conf_str = ' -conf_params'
                    for k in conf_opts.keys():
                        conf_str = '{} {} {} '.format(conf_str,k,conf_opts[k])
                else:
                    conf_str = ''

                opt_str = ''
                for k in cmd_opts.keys():
                    opt_str = '{} -{} {} '.format(opt_str,k,cmd_opts[k])

                cur_cmd = common_cmd + conf_str + opt_str + end_cmd
                cmd_name = '{}_view{}_{}'.format(exp_name,view,train_type)

                if run_type == 'submit':
                    print cur_cmd
                    print
                    run_jobs(cmd_name,cur_cmd)
                elif run_type == 'status':
                    conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
                    iter = check_train_status(cmd_name,conf.cachedir)
                    cur_info[train_type] = iter
            r_info.append(cur_info)
        info.append(r_info)


## SINGLE animals vs multiple ---- TRAINING ----

def run_single_animal_training(run_type = 'status'):

    assert data_type == 'alice'
    view = 0
    train_type = 'mdn'

    gpu_model = 'GeForceRTX2080Ti'
    sdir = '/groups/branson/home/kabram/bransonlab/APT/deepnet/singularity_stuff'

    exp_names = ['single_vs_many_fly1', 'single_vs_many_fly2', 'single_vs_many_other']

    cur_info = {}
    for exp_name in exp_names:

        common_cmd = 'APT_interface.py {} -name {} -cache {}'.format(lbl_file, exp_name, cache_dir)
        end_cmd = 'train -skip_db -use_cache'
        cmd_opts = {}
        cmd_opts['type'] = train_type
        cmd_opts['view'] = view + 1
        conf_opts = common_conf.copy()
        # conf_opts.update(other_conf[conf_id])
        conf_opts['save_step'] = conf_opts['dl_steps'] / 10
        if data_type == 'stephen':
            conf_opts['batch_size'] = 4
        if op_af_graph is not None:
            conf_opts['op_affinity_graph'] = op_af_graph

        if len(conf_opts) > 0:
            conf_str = ' -conf_params'
            for k in conf_opts.keys():
                conf_str = '{} {} {} '.format(conf_str, k, conf_opts[k])
        else:
            conf_str = ''

        opt_str = ''
        for k in cmd_opts.keys():
            opt_str = '{} -{} {} '.format(opt_str, k, cmd_opts[k])

        cur_cmd = common_cmd + conf_str + opt_str + end_cmd
        cmd_name = '{}_view{}_{}'.format(exp_name, view, train_type)

        if run_type == 'submit':
            print cur_cmd
            print
            run_jobs(cmd_name, cur_cmd)


##  ###################### GT DBs

def create_gt_db():
    lbl = h5py.File(lbl_file,'r')
    proj_name = apt.read_string(lbl['projname'])
    lbl.close()
    for view in range(nviews):
        conf = apt.create_conf(gt_lbl, view, exp_name, cache_dir, train_type)
        gt_file = os.path.join(cache_dir,proj_name,'gtdata','gtdata_view{}.tfrecords'.format(view))
        apt.create_tfrecord(conf,False,None,False,True,[gt_file])


## ######################  RESULTS


def get_normal_results():
## Normal Training  ------- RESULTS -------
    cache_dir = '/nrs/branson/mayank/apt_cache'
    exp_name = 'apt_expt'
    train_name = 'deepnet'

    all_view = []

    for view in range(nviews):
        out_exp = {}

        gt_file = os.path.join(cache_dir,proj_name,'gtdata','gtdata_view{}.tfrecords'.format(view))
        for train_type in all_models:

            conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
            # if data_type == 'stephen' and train_type == 'mdn':
            #     conf.mdn_use_unet_loss = False
            if op_af_graph is not None:
                conf.op_affinity_graph = ast.literal_eval(op_af_graph.replace('\\', ''))
            conf.normalize_img_mean = False
            files = glob.glob(os.path.join(conf.cachedir, "{}-[0-9]*").format(train_name))
            files.sort(key=os.path.getmtime)
            files = [f for f in files if os.path.splitext(f)[1] in ['.index', '']]
            aa = [int(re.search('-(\d*)',f).groups(0)[0]) for f in files]
            aa = [b-a for a,b in zip(aa[:-1],aa[1:])]
            if any([a<0 for a in aa]):
                bb = int(np.where(np.array(aa)<0)[0])+1
                files = files[bb:]
            n_max = 10
            if len(files)> n_max:
                gg = len(files)
                sel = np.linspace(0,len(files)-1,n_max).astype('int')
                files = [files[s] for s in sel]


            out_file = os.path.join(conf.cachedir,train_name + '_results.p')
            recomp = False
            if os.path.exists(out_file):
                fts = [os.path.getmtime(f) for f in files]
                ots = os.path.getmtime(out_file)
                if any([f > ots for f in fts]):
                    recomp = True
                else:
                    A = PoseTools.pickle_load(out_file)
                    old_files = A[1]
                    if not all([i==j for i,j in zip(files,old_files)]):
                        recomp = True
            else:
                recomp = True

            # recomp = False

            if recomp:
                afiles = [f.replace('.index', '') for f in files]
                mdn_out = apt_expts.classify_db_all(conf,gt_file,afiles,train_type,name=train_name)
                with open(out_file,'w') as f:
                    pickle.dump([mdn_out,files],f)
            else:
                A = PoseTools.pickle_load(out_file)
                mdn_out = A[0]

            out_exp[train_type] = mdn_out
        all_view.append(out_exp)

    for ndx,out_exp in enumerate(all_view):
        plot_results(out_exp)
        save_mat(out_exp,os.path.join(cache_dir,'{}_view{}_time'.format(data_type,ndx,)))

## DLC AUG vs no aug --- RESULTS -----

def get_dlc_results():
    cmd_str = ['dlc_aug','dlc_noaug']
    exp_name = 'apt_expt'

    train_type = 'deeplabcut'
    for view in range(nviews):
        dlc_exp = {}

        gt_file = os.path.join(cache_dir,proj_name,'gtdata','gtdata_view{}.tfrecords'.format(view))

        for conf_id in range(len(cmd_str)):
            train_name=cmd_str[conf_id]
            conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
            if op_af_graph is not None:
                conf.op_affinity_graph = ast.literal_eval(op_af_graph.replace('\\', ''))
            files = glob.glob(os.path.join(conf.cachedir, "{}-[0-9]*").format(train_name))
            files.sort(key=os.path.getmtime)
            files = [f for f in files if os.path.splitext(f)[1] in ['.index', '']]
            aa = [int(re.search('-(\d*)',f).groups(0)[0]) for f in files]
            aa = [b - a for a, b in zip(aa[:-1], aa[1:])]
            if any([a < 0 for a in aa]):
                bb = int(np.where(np.array(aa) < 0)[0]) + 1
                files = files[bb:]

            if len(files) > 8:
                gg = len(files)
                sel = np.linspace(0, len(files) - 1, 8).astype('int')
                files = [files[s] for s in sel]

            out_file = os.path.join(conf.cachedir,train_name + '_results.p')
            recomp = False
            if os.path.exists(out_file):
                fts = [os.path.getmtime(f) for f in files]
                ots = os.path.getmtime(out_file)
                if any([f > ots for f in fts]):
                    recomp = True
                else:
                    A = PoseTools.pickle_load(out_file)
                    old_files = A[1]
                    if not all([i==j for i,j in zip(files,old_files)]):
                        recomp = True

            if recomp:
                afiles = [f.replace('.index', '') for f in files]
                mdn_out = apt_expts.classify_db_all(conf,gt_file,afiles,train_type,name=train_name)
                with open(out_file,'w') as f:
                    pickle.dump([mdn_out,files],f)
            else:
                A = PoseTools.pickle_load(out_file)
                mdn_out = A[0]

            dlc_exp[train_name] = mdn_out
        plot_results(dlc_exp)

## incremental training -- RESULTS ---


def get_incremental_results():
    n_rounds = 8
    all_res = []
    train_name = 'deepnet'
    all_view = []

    for view in range(nviews):
        out_exp = {}
        gt_file = os.path.join(cache_dir, proj_name, 'gtdata', 'gtdata_view{}.tfrecords'.format(view))
        inc_exp = {}
        for train_type in all_models:
            # if data_type == 'alice' and train_type == 'leap':
            #     continue
            r_files = []
            train_size = []
            for ndx in range(n_rounds):
                exp_name = '{}_randsplit_round_{}'.format(data_type, ndx)
                conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
                split_data = PoseTools.json_load(os.path.join(conf.cachedir,'splitdata.json'))
                train_size.append(len(split_data[0]))
                if op_af_graph is not None:
                    conf.op_affinity_graph = ast.literal_eval(op_af_graph.replace('\\', ''))
                files = glob.glob(os.path.join(conf.cachedir, "{}-[0-9]*").format(train_name))
                files.sort(key=os.path.getmtime)
                files = [f for f in files if os.path.splitext(f)[1] in ['.index', '']]
                aa = [int(re.search('-(\d*)', f).groups(0)[0]) for f in files]
                if len(files)>0 and aa[-1]>0:
                    r_files.append(files[-1])
                else:
                    print('MISSING!!!! MISSING!!!! {} {}'.format(train_type,ndx))

            out_file = os.path.join(conf.cachedir,train_name + '_results.p')
            recomp = False
            if os.path.exists(out_file):
                fts = [os.path.getmtime(f) for f in r_files]
                ots = os.path.getmtime(out_file)
                if any([f > ots for f in fts]):
                    recomp = True
                else:
                    A = PoseTools.pickle_load(out_file)
                    old_files = A[1]
                    if (len(r_files) != len(old_files)) or (not all([i==j for i,j in zip(r_files,old_files)])):
                        recomp = True
            else:
                recomp = True

            if recomp:
                afiles = [f.replace('.index', '') for f in r_files]
                mdn_out = apt_expts.classify_db_all(conf,gt_file,afiles,train_type,name=train_name)
                with open(out_file,'w') as f:
                    pickle.dump([mdn_out,r_files],f)
            else:
                A = PoseTools.pickle_load(out_file)
                mdn_out = A[0]

            # mdn_out = apt_expts.classify_db_all(conf, gt_file, r_files, train_type, name=train_name)

            for x, a in enumerate(mdn_out):
                a[-1] = train_size[x]
            mdn_out.insert(0,mdn_out[0])
            inc_exp[train_type] = mdn_out
        all_view.append(inc_exp)

    for ndx,ii in enumerate(all_view):
        plot_results(ii,ylim=15)
        save_mat(ii,os.path.join(cache_dir,'{}_view{}_trainsize'.format(data_type,ndx,)))


## CV Results

def get_cv_results():
    train_name = 'deepnet'

    assert gt_lbl is None
    all_view = []
    for view in range(nviews):
        out_exp = {}
        for tndx in range(len(all_models)):
            train_type = all_models[tndx]

            out_split = None
            for split in range(n_splits):
                exp_name = 'cv_split_{}'.format(split)
                mdn_conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, 'mdn')
                conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)

                if op_af_graph is not None:
                    conf.op_affinity_graph = ast.literal_eval(op_af_graph.replace('\\', ''))
                files = glob.glob(os.path.join(conf.cachedir, "{}-[0-9]*").format(train_name))
                files.sort(key=os.path.getmtime)
                files = [f for f in files if os.path.splitext(f)[1] in ['.index', '']]
                aa = [int(re.search('-(\d*)',f).groups(0)[0]) for f in files]
                aa = [b-a for a,b in zip(aa[:-1],aa[1:])]
                if any([a<0 for a in aa]):
                    bb = int(np.where(np.array(aa)<0)[0])+1
                    files = files[bb:]
                n_max = 10
                if len(files)> n_max:
                    gg = len(files)
                    sel = np.linspace(0,len(files)-1,n_max).astype('int')
                    files = [files[s] for s in sel]

                out_file = os.path.join(conf.cachedir,train_name + '_results.p')
                recomp = False
                if os.path.exists(out_file):
                    fts = [os.path.getmtime(f) for f in files]
                    ots = os.path.getmtime(out_file)
                    if any([f > ots for f in fts]):
                        recomp = True
                    else:
                        A = PoseTools.pickle_load(out_file)
                        old_files = A[1]
                        if not all([i==j for i,j in zip(files,old_files)]):
                            recomp = True
                else:
                    recomp = True

                if recomp:
                    afiles = [f.replace('.index', '') for f in files]
                    db_file = os.path.join(mdn_conf.cachedir,'val_TF.tfrecords')
                    mdn_out = apt_expts.classify_db_all(conf,db_file,afiles,train_type,name=train_name)
                    with open(out_file,'w') as f:
                        pickle.dump([mdn_out,files],f)
                else:
                    A = PoseTools.pickle_load(out_file)
                    mdn_out = A[0]
                if out_split is None:
                    out_split = mdn_out
                else:
                    for mndx in range(len(mdn_out)):
                        out_split[mndx][0] = np.append(out_split[mndx][0],mdn_out[mndx][0],axis=0)
                        out_split[mndx][1] = np.append(out_split[mndx][1],mdn_out[mndx][1],axis=0)

            out_exp[train_type] = out_split
        all_view.append(out_exp)

    for ndx,out_exp in enumerate(all_view):
        plot_results(out_exp)
        save_mat(out_exp,os.path.join(cache_dir,'{}_view{}_cv'.format(data_type,ndx,)))


## single vs multiple animal ----RESULTS
def get_single_results():
    import multiResData
    assert data_type == 'alice'
    view = 0
    train_type = 'mdn'

    gpu_model = 'GeForceRTX2080Ti'
    sdir = '/groups/branson/home/kabram/bransonlab/APT/deepnet/singularity_stuff'
    common_conf = {}
    common_conf['rrange'] = 10
    common_conf['trange'] = 5
    common_conf['mdn_use_unet_loss'] = True
    common_conf['dl_steps'] = 60000
    common_conf['decay_steps'] = 20000
    common_conf['save_step'] = 5000
    common_conf['batch_size'] = 8
    common_conf['maxckpt'] = 20

    exp_names = ['single_vs_many_fly1', 'single_vs_many_fly2', 'single_vs_many_other']

    out_exp = {}
    train_name = 'deepnet'
    all_view = []
    for exp_name in exp_names:

        conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, 'mdn')
        if op_af_graph is not None:
            conf.op_affinity_graph = ast.literal_eval(op_af_graph.replace('\\', ''))
        files = glob.glob(os.path.join(conf.cachedir, "{}-[0-9]*").format(train_name))
        files.sort(key=os.path.getmtime)
        files = [f for f in files if os.path.splitext(f)[1] in ['.index', '']]
        aa = [int(re.search('-(\d*)', f).groups(0)[0]) for f in files]
        aa = [b - a for a, b in zip(aa[:-1], aa[1:])]
        if any([a < 0 for a in aa]):
            bb = int(np.where(np.array(aa) < 0)[0]) + 1
            files = files[bb:]
        files = files[-1:]

        out_file = os.path.join(conf.cachedir, train_name + '_results.p')
        recomp = False
        if os.path.exists(out_file):
            fts = [os.path.getmtime(f) for f in files]
            ots = os.path.getmtime(out_file)
            if any([f > ots for f in fts]):
                recomp = True
            else:
                A = PoseTools.pickle_load(out_file)
                old_files = A[1]
                if not all([i == j for i, j in zip(files, old_files)]):
                    recomp = True
        else:
            recomp = True

        db_file = os.path.join(conf.cachedir, 'val_TF.tfrecords')
        H = multiResData.read_and_decode_without_session(db_file,conf,())
        info = np.array(H[2])
        if recomp:
            afiles = [f.replace('.index', '') for f in files]
            mdn_out = apt_expts.classify_db_all(conf, db_file, afiles, train_type, name=train_name)
            with open(out_file, 'w') as f:
                pickle.dump([mdn_out, files], f)
        else:
            A = PoseTools.pickle_load(out_file)
            mdn_out = A[0]
        mdn_out[0].append(info)
        out_exp[exp_name] = mdn_out

    all_view.append(out_exp)

    for ndx, out_exp in enumerate(all_view):
        save_mat(out_exp, os.path.join(cache_dir, '{}_view{}_single_vs_multiple'.format(data_type, ndx, )))

#

    fly1 = [0,3]
    fly2 = [2,8]

    fly1_res = {}
    fly2_res = {}
    other_res = {}

    splits = []
    for exp_name in exp_names:
        conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, 'mdn')
        splitfile = os.path.join(conf.cachedir,'splitdata.json')
        splits.append(PoseTools.json_load(splitfile))


    for exp_name in exp_names:
        mdn_out = out_exp[exp_name][0]
        dd = np.sqrt(np.sum((mdn_out[0]-mdn_out[1])**2,axis=-1))
        nex = mdn_out[0].shape[0]
        fly1_res[exp_name]= []
        fly2_res[exp_name]= []
        other_res[exp_name]= []
        for ndx in range(nex):
            cur_m = mdn_out[-1][ndx][0]
            cur_t = mdn_out[-1][ndx][2]
            cur_i = mdn_out[-1][ndx].tolist()
            if all([cur_i in s[1] for s in splits]):
                if [cur_m,cur_t] == fly1:
                    fly1_res[exp_name].append(dd[ndx,:])
                elif [cur_m,cur_t] ==fly2:
                    fly2_res[exp_name].append(dd[ndx,:])
                else:
                    other_res[exp_name].append(dd[ndx,:])


    percs = [50,75,90,95]
    per_res = []
    all_res = []
    for ndx, exp_name in enumerate(exp_names):
        gg = []
        gg.append(np.percentile(fly1_res[exp_name],percs,axis=0))
        gg.append(np.percentile(fly2_res[exp_name],percs,axis=0))
        gg.append(np.percentile(other_res[exp_name],percs,axis=0))
        per_res.append(np.array(gg))
        gg = []
        gg.append(fly1_res[exp_name])
        gg.append(fly2_res[exp_name])
        gg.append(other_res[exp_name])
        all_res.append(np.array(gg))

    per_res = np.array(per_res)


    #
    f,ax = plt.subplots(1,3,sharex=True,sharey=True)
    ax = ax.flatten()
    trange = np.arange(0,5,0.25)
    for count in range(3):
        if count == 0:
            cur_res = fly1_res
        elif count == 1:
            cur_res =fly2_res
        else:
            cur_res = other_res
        base_res = cur_res[exp_names[count]]
        ad = []
        for exp_name in exp_names:
            dd = np.array(cur_res[exp_name])-np.array(base_res)
            ad = []
            for tr in trange:
                cur_ad = np.count_nonzero(dd.flat>tr) - np.count_nonzero(dd.flat<-tr)
                ad.append(cur_ad/float(dd.flatten().size))
            ax[count].plot(trange,ad)


#
    import hdf5storage
    save_names = [u'train_fly1',u'train_fly2',u'train_others']
    out_dict = {}
    for ndx,exp_name in enumerate(exp_names):
        cur_dict = {}
        cur_dict[u'dist_fly1'] = np.array(fly1_res[exp_name])
        cur_dict[u'dist_fly2'] = np.array(fly2_res[exp_name])
        cur_dict[u'dist_flyothers'] = np.array(other_res[exp_name])
        out_dict[save_names[ndx]] = cur_dict

    hdf5storage.savemat(os.path.join(cache_dir,'alice_single_vs_multiple_results.mat'), out_dict, truncate_existing=True)


def run_active_learning(round_num,add_type='active'):

    assert data_type is 'alice'
    import random
    import json

    n_add = 20
    view = 0
    exp_name = 'active_round0'
    common_conf = apt.create_conf(lbl_file, 0, exp_name, cache_dir, 'mdn')
    train_type = 'mdn'
    train_name = 'deepnet'

    if round_num == 0:
        out_file = os.path.join(common_conf.cachedir,'initital_split.json')

        if add_type == 'active':
            info = get_label_info(common_conf)
            random.shuffle(info)
            train_split = info[:n_add]
            val_split = info[n_add:]
            splits = [train_split, val_split]
            assert not os.path.exists(out_file)
            with open(out_file, 'w') as f:
                json.dump(splits, f)
            exp_name = 'active_round{}'.format(round_num)
        else:
            exp_name = 'random_round{}'.format(round_num)

        conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
        conf.splitType = 'predefined'
        if train_type == 'deeplabcut':
            apt.create_deepcut_db(conf, split=True, use_cache=True, split_file=out_file)
        elif train_type == 'leap':
            apt.create_leap_db(conf, split=True, use_cache=True, split_file=out_file)
        else:
            apt.create_tfrecord(conf, split=True, use_cache=True, split_file=out_file)

        run_trainining(exp_name,train_type,view=0,run_type='submit',dl_steps=20000)

    else:

        if add_type == 'active':
            prev_exp = 'active_round{}'.format(round_num-1)
            exp_name = 'active_round{}'.format(round_num)
        else:
            prev_exp = 'random_round{}'.format(round_num-1)
            exp_name = 'random_round{}'.format(round_num)

        # find the worse validation examples
        prev_conf = apt.create_conf(lbl_file, view, prev_exp, cache_dir, train_type)
        prev_splits = PoseTools.json_load(os.path.join(prev_conf.cachedir,'splitdata.json'))
        if op_af_graph is not None:
            prev_conf.op_affinity_graph = ast.literal_eval(op_af_graph.replace('\\', ''))
        files = glob.glob(os.path.join(prev_conf.cachedir, "{}-[0-9]*").format(train_name))
        files.sort(key=os.path.getmtime)
        files = [f for f in files if os.path.splitext(f)[1] in ['.index', '']]
        aa = [int(re.search('-(\d*)', f).groups(0)[0]) for f in files]
        aa = [b - a for a, b in zip(aa[:-1], aa[1:])]
        if any([a < 0 for a in aa]):
            bb = int(np.where(np.array(aa) < 0)[0]) + 1
            files = files[bb:]
        files = files[-1:]

        afiles = [f.replace('.index', '') for f in files]
        db_file = os.path.join(prev_conf.cachedir, 'val_TF.tfrecords')
        mdn_out = apt_expts.classify_db_all(prev_conf, db_file, afiles, train_type, name=train_name)
        res = mdn_out[0]
        val_info = res[2]
        dd = np.sqrt(np.sum((res[0]-res[1])**2,axis=-1))
        tot_dd = np.sum(dd,axis=-1)
        ord_dd = np.argsort(tot_dd)

        if add_type == 'active':
            # add the worst examples to training set
            sel_ex = ord_dd[-n_add:]
        else:
            sel_ex = random.sample(range(len(ord_dd)),n_add)

        train_add = [val_info[ss][0].tolist() for ss in sel_ex]
        new_val = [val_info[ss][0].tolist() for ss in ord_dd[:-n_add]]
        new_train = prev_splits[0] + train_add
        new_splits = [new_train,new_val]
        conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
        out_split_file = os.path.join(conf.cachedir,'current_split.json')
        with open(out_split_file,'w') as f:
            json.dump(new_splits,f)

        conf.splitType = 'predefined'
        if train_type == 'deeplabcut':
            apt.create_deepcut_db(conf, split=True, use_cache=True, split_file=out_split_file)
        elif train_type == 'leap':
            apt.create_leap_db(conf, split=True, use_cache=True, split_file=out_split_file)
        else:
            apt.create_tfrecord(conf, split=True, use_cache=True, split_file=out_split_file)

        run_trainining(exp_name,train_type,view=0,run_type='submit',dl_steps=20000)






def get_label_info(conf):
    from scipy import io as sio
    local_dirs, _ = multiResData.find_local_dirs(conf)
    lbl = h5py.File(conf.labelfile, 'r')

    mov_info = []
    trx_info = []
    n_labeled_frames = 0
    for ndx, dir_name in enumerate(local_dirs):
        if conf.has_trx_file:
            trx_files = multiResData.get_trx_files(lbl, local_dirs)
            trx = sio.loadmat(trx_files[ndx])['trx'][0]
            n_trx = len(trx)
        else:
            n_trx = 1

        cur_mov_info = []
        for trx_ndx in range(n_trx):
            frames = multiResData.get_labeled_frames(lbl, ndx, trx_ndx)
            mm = [ndx] * frames.size
            tt = [trx_ndx] * frames.size
            cur_trx_info = list(zip(mm, frames.tolist(), tt))
            trx_info.append(cur_trx_info)
            cur_mov_info.extend(cur_trx_info)
            n_labeled_frames += frames.size
        mov_info.append(cur_mov_info)
    lbl.close()

    info = []

    for ndx in range(len(local_dirs)):
        for mndx in range(len(mov_info[ndx])):
            info.extend(mov_info[ndx][mndx:mndx + 1])

    return info