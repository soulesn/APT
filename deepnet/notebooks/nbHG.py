
import h5py
import os
import json
import datetime
import pickle

import numpy as np

import run_apt_expts as rapt
import apt_expts as apt_expts
import APT_interface as apt
import multiResData
import PoseTools

gpu_model = 'GeForceRTX2080Ti'

all_models = ['mdn', 'deeplabcut', 'unet', 'leap', 'openpose', 'resnet_unet', 'hg']
cache_dir = '/groups/branson/home/leea30/apt/posebase20190528/cache_20190702_hgrfn_long'
run_dir = '/groups/branson/home/leea30/apt/posebase20190528/out_20190702_hgrfn_long'
apt_deepnet_root = '/groups/branson/home/leea30/git/aptFtrDT/deepnet'

lblbub = '/groups/branson/bransonlab/apt/experiments/data/multitarget_bubble_expandedbehavior_20180425_FxdErrs_OptoParams20181126_dlstripped.lbl'
lblsh = '/groups/branson/bransonlab/apt/experiments/data/sh_trn4992_gtcomplete_cacheddata_updated20190402_dlstripped.lbl'

cvibub = '/groups/branson/home/leea30/apt/posebase20190528/cvi_outer3_easy.mat'
cvishE = '/groups/branson/home/leea30/apt/posebase20190528/cvi_sh_4523_outer3_easy.mat'
cvishH = '/groups/branson/home/leea30/apt/posebase20190528/cvi_sh_4523_outer3_hard.mat'

def read_cvinfo(lbl_file, cv_info_file, view=0):
    data_info = h5py.File(cv_info_file, 'r')
    cv_info = apt.to_py(data_info['cvi'].value[:, 0].astype('int'))
    n_splits = max(cv_info) + 1

    conf = apt.create_conf(lbl_file, view, 'cv_dummy', cache_dir, 'mdn')  # net type irrelevant
    lbl_movies, _ = multiResData.find_local_dirs(conf)
    #in_movies = [PoseTools.read_h5_str(data_info[k]) for k in data_info['movies'][0, :]]
    #assert lbl_movies == in_movies

    label_info = rapt.get_label_info(conf)
    fr_info = apt.to_py(data_info['frame'].value[:, 0].astype('int'))
    m_info = apt.to_py(data_info['movieidx'].value[:, 0].astype('int'))
    if 'target' in data_info.keys():
        t_info = apt.to_py(data_info['target'].value[:, 0].astype('int'))
        in_info = [(a, b, c) for a, b, c in zip(m_info, fr_info, t_info)]
    else:
        in_info = [(a, b, 0) for a, b in zip(m_info, fr_info)]
    diff1 = list(set(label_info)-set(in_info))
    diff2 = list(set(in_info)-set(label_info))
    print('Number of labels that exists in label file but not in mat file:{}'.format(len(diff1)))
    print('Number of labels that exists in mat file but not in label file:{}'.format(len(diff2)))
    # assert all([a == b for a, b in zip(in_info, label_info)])

    return cv_info, in_info, label_info


def cv_train_from_mat(lbl_file, cv_info_file, models_run,
                      view=0, skip_db=False, create_splits=True, dorun=False, run_type='status'):

    cv_info, in_info, label_info = read_cvinfo(lbl_file, cv_info_file, view)

    lbl = h5py.File(lbl_file, 'r')
    proj_name = apt.read_string(lbl['projname'])
    lbl.close()

    cvifileshort = os.path.basename(cv_info_file)
    cvifileshort = os.path.splitext(cvifileshort)[0]

    n_splits = max(cv_info) + 1

    print("{} splits, {} rows in cvi, {} rows in lbl, projname {}".format(n_splits, len(cv_info), len(label_info), proj_name))

    for sndx in range(n_splits):
        val_info = [l for ndx, l in enumerate(in_info) if cv_info[ndx]==sndx]
        trn_info = list(set(label_info)-set(val_info))
        cur_split = [trn_info, val_info]
        exp_name = '{:s}__split{}'.format(cvifileshort, sndx)
        split_file = os.path.join(cache_dir, proj_name, exp_name) + '.json'
        if not skip_db and create_splits:
            assert not os.path.exists(split_file)
            with open(split_file, 'w') as f:
                json.dump(cur_split, f)

        # create the dbs
        if not skip_db:
            for train_type in models_run:
                conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
                conf.splitType = 'predefined'
                if train_type == 'deeplabcut':
                    apt.create_deepcut_db(conf, split=True, split_file=split_file, use_cache=True)
                elif train_type == 'leap':
                    apt.create_leap_db(conf, split=True, split_file=split_file, use_cache=True)
                else:
                    apt.create_tfrecord(conf, split=True, split_file=split_file, use_cache=True)
        if dorun:
            for train_type in models_run:
                rapt.run_trainining(exp_name, train_type, view, run_type)


def run_jobs(cmd_name, cur_cmd, redo=False):

    nowstr = datetime.datetime.now().strftime("%Y%m%dT%H%M%S%f")
    cmd_name_ts = '{}_{}'.format(cmd_name, nowstr)
    # basestr = 'opt_{}_{}'.format(cmd_name, nowstr)
    # logfile = os.path.join(run_dir, basestr + '.log')
    # errfile = os.path.join(run_dir, basestr + '.err')

    # run = False
    # if redo:
    #     run = True
    # elif not os.path.exists(errfile):
    #     run = True
    # else:
    #     ff = open(errfile,'r').read().lower()
    #     if ff.find('error'):
    #         run = True
    #     else:
    #         run = False
    #
    # if run:
    PoseTools.submit_job(cmd_name_ts, cur_cmd, run_dir, gpu_model=gpu_model, run_dir=apt_deepnet_root)
    # else:
    #     print('NOT submitting job {}'.format(cmd_name))


def run_training(lbl_file, exp_name, data_type, train_type, view, run_type, **kwargs):

    common_cmd = 'APT_interface.py {} -name {} -cache {}'.format(lbl_file, exp_name, cache_dir)
    end_cmd = 'train -skip_db -use_cache'

    cmd_opts = {}
    cmd_opts['type'] = train_type
    cmd_opts['view'] = view + 1

    conf_opts = rapt.common_conf.copy()
    # conf_opts.update(other_conf[conf_id])
    conf_opts['save_step'] = conf_opts['dl_steps'] / 10
    for k in kwargs.keys():
        conf_opts[k] = kwargs[k]

    # if data_type in ['brit0' ,'brit1','brit2']:
    #     conf_opts['adjust_contrast'] = True
    #     if train_type == 'unet':
    #         conf_opts['batch_size'] = 2
    #     else:
    #         conf_opts['batch_size'] = 4

    # if data_type in ['romain']:
    #     if train_type in ['mdn','resnet_unet']:
    #         conf_opts['batch_size'] = 2
    #     elif train_type in ['unet']:
    #         conf_opts['batch_size'] = 1
    #     else:
    #         conf_opts['batch_size'] = 4
    #
    # if data_type in ['larva']:
    #     conf_opts['batch_size'] = 4
    #     conf_opts['adjust_contrast'] = True
    #     conf_opts['clahe_grid_size'] = 20
    #     if train_type in ['unet','resnet_unet','leap']:
    #         conf_opts['rescale'] = 2
    #         conf_opts['batch_size'] = 2
    #     if train_type in ['mdn']:
    #         conf_opts['batch_size'] = 4
    #         conf_opts['rescale'] = 2
    #         conf_opts['mdn_use_unet_loss'] = True
    #         # conf_opts['mdn_learning_rate'] = 0.0001
    #
    # if data_type == 'stephen':
    #     conf_opts['batch_size'] = 4

    # if data_type == 'carsen':
    #     if train_type in ['mdn','unet','resnet_unet']:
    #         conf_opts['rescale'] = 2.
    #     else:
    #         conf_opts['rescale'] = 1.
    #     conf_opts['adjust_contrast'] = True
    #     conf_opts['clahe_grid_size'] = 20
    #     if train_type in ['unet']:
    #         conf_opts['batch_size'] = 4
    #     else:
    #         conf_opts['batch_size'] = 8
    #
    # if op_af_graph is not None:
    #     conf_opts['op_affinity_graph'] = op_af_graph

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
    if run_type == 'dry':
        print cmd_name
        print cur_cmd
        print
    elif run_type == 'submit':
        print cmd_name
        print cur_cmd
        print
        run_jobs(cmd_name, cur_cmd)
    elif run_type == 'status':
        conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, train_type)
        check_train_status(cmd_name, conf.cachedir)


def save_cv_results(lbl_file, view, exp_name, net, model_file_short, out_dir, conf_pvlist=None):
    conf = apt.create_conf(lbl_file, view, exp_name, cache_dir, net, conf_params=conf_pvlist)
    db_file = os.path.join(conf.cachedir, 'val_TF.tfrecords')
    model_file = os.path.join(conf.cachedir, model_file_short)
    res = apt_expts.classify_db_all(conf, db_file, [model_file], net)
    out_file = "{}__vw{}__{}.p".format(exp_name, view, net)
    out_file = os.path.join(out_dir, out_file)
    with open(out_file, 'w') as f:
        pickle.dump(res, f)
    print "saved {}".format(out_file)


def perf(out_dir, expname_pat_splits, num_splits, n_classes):
    for split in range(num_splits):
        if split == 0:
            ptrk = np.zeros((0, n_classes, 2))
            plbl = np.zeros((0, n_classes, 2))
            mft = np.zeros((0, 1, 3))

        out_file = expname_pat_splits.format(split)
        out_file = os.path.join(out_dir, out_file)
        print "loading {}".format(out_file)
        with open(out_file, 'r') as f:
            res = pickle.load(f)
        ptrk = np.concatenate((ptrk, res[0][0]))
        plbl = np.concatenate((plbl, res[0][1]))
        mft = np.concatenate((mft, res[0][2]))

    err = np.sqrt(np.sum((ptrk-plbl)**2, 2))
    results = {
        'ptrk': ptrk,
        'plbl': plbl,
        'mft': mft,
        'd': ptrk-plbl,
        'err': err,
        'ptiles': np.percentile(err, [50, 90, 95, 98], axis=0)
    }
    return results


