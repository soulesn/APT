import os
import math
import matplotlib.pyplot as plt
import numpy as np
import datetime
import tensorflow as tf
import json
import logging
import shutil
import argparse
import sys
import pickle

import tensorflow.keras as tfk
import imgaug.augmenters as iaa
import imgaug as ia
import deepposekit.io.DataGenerator
import deepposekit.io.TrainingGenerator
from deepposekit.augment import FlipAxis
import deepposekit.callbacks
from deepposekit.models import StackedDenseNet

import TrainingGeneratorTFRecord as TGTFR
import opdata2 as opd
import open_pose4 as op4
import heatmap as hm
import PoseTools
import multiResData
import poseConfig
import APT_interface as apt


bubtouchroot = '/groups/branson/home/leea30/apt/ar_flybub_touching_op_20191111'
lblbubtouch = os.path.join(bubtouchroot,'20191125T170226_20191125T170453.lbl')
cvitouch = os.path.join(bubtouchroot,'cvi_trn4702_tst180.mat')
kwtouch = '20191125_base_trn4702tst180'
cdirtouch = os.path.join(bubtouchroot, 'cdir' + kwtouch)
outtouch = os.path.join(bubtouchroot, 'out' + kwtouch)
exptouch = 'cvi_trn4702_tst180__split1' # trn4702, tst180

cacheroot = '/nrs/branson/al/aptcache'
dpk_fly_h5 = '/groups/branson/home/leea30/git/dpkd/datasets/fly/annotation_data_release.h5'

isotri='/groups/branson/home/leea30/apt/dpk20191114/isotri.png'
isotrilocs = np.array([[226., 107.], [180., 446.], [283., 445.]])
isotriswapidx = np.array([-1, 2, 1])

def viz_targets(ims, tgts, npts, ngrps, ibatch=0):
    '''

    :param ims: [nb x h x w x nchan] images generated by generator
    :param tgts: [nb x hds x wds x nmap] Hmap targets generated by generator
    :return:
    '''

    #n_keypoints = data_generator.keypoints_shape[0]
    n_keypoints = npts

    #batch = train_generator(batch_size=1, validation=False)[1]
    #inputs = batch[0]
    #outputs = batch[1]
    inputs = ims
    outputs = tgts

    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(10, 10))
    ax1.set_title('image')
    ax1.imshow(inputs[ibatch, ..., 0], cmap='gray', vmin=0, vmax=255)

    ax2.set_title('posture graph')
    ax2.imshow(outputs[ibatch, ..., n_keypoints:-1].max(-1))

    ax3.set_title('keypoints confidence')
    ax3.imshow(outputs[ibatch, ..., :n_keypoints].max(-1))

    ax4.set_title('posture graph and keypoints confidence')
    ax4.imshow(outputs[ibatch, ..., -1], vmin=0)
    plt.show()

    #kp
    minkpthmap = np.min(outputs[ibatch, ..., :npts])
    maxkpthmap = np.max(outputs[ibatch, ..., :npts])
    print("kpthmap min/max is {}/{}".format(minkpthmap, maxkpthmap))
    axnr = 3
    axnc = math.ceil(npts/axnr)
    figkp, axs = plt.subplots(axnr, axnc)
    axsflat = axs.flatten()
    for ipt in range(n_keypoints):
        im = axsflat[ipt].imshow(outputs[ibatch, ..., ipt],
                            vmin=minkpthmap,
                            vmax=maxkpthmap)
        axsflat[ipt].set_title("pt{}".format(ipt))
        if ipt == 0:
            figkp.colorbar(im)
    plt.show()

    #grps
    mingrps = np.min(outputs[ibatch, ..., npts:npts+ngrps])
    maxgrps = np.max(outputs[ibatch, ..., npts:npts+ngrps])
    print("grps min/max is {}/{}".format(mingrps, maxgrps))
    axnr = 1
    axnc = math.ceil(ngrps/axnr)
    figgrps, axs = plt.subplots(axnr, axnc)
    axsflat = axs.flatten()
    for i in range(ngrps):
        im = axsflat[i].imshow(outputs[ibatch, ..., npts+i],
                               vmin=mingrps,
                               vmax=maxgrps)
        axsflat[i].set_title("grp{}".format(i))
        if i == 0:
            figgrps.colorbar(im)
    plt.show()

    # limbs
    nlimbs = outputs.shape[-1] - npts - ngrps - 2
    minlimbs = np.min(outputs[ibatch, ..., npts+ngrps:npts+ngrps+nlimbs])
    maxlimbs = np.max(outputs[ibatch, ..., npts+ngrps:npts+ngrps+nlimbs])
    print("limbs min/max is {}/{}".format(minlimbs, maxlimbs))
    axnr = 3
    axnc = math.ceil(nlimbs / axnr)
    figlimbs, axs = plt.subplots(axnr, axnc)
    axsflat = axs.flatten()
    for i in range(nlimbs):
        im = axsflat[i].imshow(outputs[ibatch, ..., npts+ngrps+i],
                               vmin=minlimbs,
                               vmax=maxlimbs)
        axsflat[i].set_title("limb{}".format(i))
        if i == 0:
            figlimbs.colorbar(im)
    plt.show()

    # globals
    nglobs = 2
    minglobs = np.min(outputs[ibatch, ..., -2:])
    maxglobs = np.max(outputs[ibatch, ..., -2:])
    print("globs min/max is {}/{}".format(minglobs, maxglobs))
    axnr = 1
    axnc = math.ceil(nglobs / axnr)
    figglobs, axs = plt.subplots(axnr, axnc)
    axsflat = axs.flatten()
    for i in range(nglobs):
        im = axsflat[i].imshow(outputs[ibatch, ..., -2+i])
        axsflat[i].set_title("glob{}".format(i))
        figglobs.colorbar(im, ax=axsflat[i])
    plt.show()

    return figkp, figgrps, figlimbs, figglobs

def viz_skel(ims, locs, graph):
    image = ims
    keypoints = locs

    plt.figure(figsize=(5, 5))
    image = image7[0] if image.shape[-1] is 3 else image[0, ..., 0]
    cmap = None if image.shape[-1] is 3 else 'gray'
    plt.imshow(image, cmap=cmap, interpolation='none')
    for idx, jdx in enumerate(graph):
        if jdx > -1:
            plt.plot(
                [keypoints[0, idx, 0], keypoints[0, jdx, 0]],
                [keypoints[0, idx, 1], keypoints[0, jdx, 1]],
                'r-'
            )
    plt.scatter(keypoints[0, :, 0], keypoints[0, :, 1],
                c=np.arange(keypoints.shape[1]),
                s=50,
                cmap=plt.cm.hsv,
                zorder=3)

    plt.show()

def toymodel(nout):
    X = tfk.Input(shape=(10, 10, 1), name='img')
    inputs = [X,]
    outputs = []
    for i in range(nout):
        X = tfk.layers.Conv2D(8, 3,
                              padding='same',
                              activation='relu',
                              name='out{}'.format(i),
                              kernel_initializer='random_uniform')(X)
        outputs.append(X)

    model = tfk.Model(inputs=inputs, outputs=outputs, name='toymodel')

    model.compile("adam", "mse")
    return model

def toy(m):

    nout = len(m.outputs)
    x = tf.constant(np.random.normal(size=(6, 10, 10, 1)))
    y = [tf.constant(np.random.normal(size=(6, 10, 10, 8))) for i in range(nout)]

    yp0 = m.predict_on_batch(x)
    yp1 = m.predict_on_batch(x)
    if nout==1:
        yp0 = [yp0,]
        yp1 = [yp1,]
    losses = m.evaluate(x, y, steps=1)
    with tf.Session().as_default():
        ye0 = [x.eval() for x in y]
    with tf.Session().as_default():
        ye1 = [x.eval() for x in y]

    print('mse of yp0 and yp1 els')
    for x, y in zip(yp0, yp1):
        print(np.mean((x-y)**2))

    print('mse of ye0 and ye1 els')
    for x, y in zip(ye0, ye1):
        print(np.mean((x-y)**2))

    print('losses per evaluate: {}'.format(losses))
    print('losses evaled manually:')
    for x, y in zip(ye0, yp0):
        print(np.mean((x-y)**2))

    return yp0, ye0, losses, x, y

def check_flips(im, locs, dpk_swap_index):
    im_lr = im.copy()
    im_ud = im.copy()
    im_lria = im.copy()
    im_udia = im.copy()
    locs_lr = locs.copy()
    locs_ud = locs.copy()
    locs_lria = locs.copy()
    locs_udia = locs.copy()

    augmenter_ud = [FlipAxis(dpk_swap_index, axis=0, p=1.0)]
    augmenter_lr = [FlipAxis(dpk_swap_index, axis=1, p=1.0)]
    augmenter_ud = iaa.Sequential(augmenter_ud)
    augmenter_lr = iaa.Sequential(augmenter_lr)

    im_lr, locs_lr = PoseTools.randomly_flip_lr(im_lr, locs_lr)
    im_ud, locs_ud = PoseTools.randomly_flip_ud(im_ud, locs_ud)
    im_lria, locs_lria = opd.imgaug_augment(augmenter_lr, im_lria, locs_lria)
    im_udia, locs_udia = opd.imgaug_augment(augmenter_ud, im_udia, locs_udia)

    return (im_lr, locs_lr), (im_ud, locs_ud), (im_lria, locs_lria), (im_udia, locs_udia)

def create_callbacks(sdn, conf):

    logging.warning("configing callbacks")

    # `Logger` evaluates the validation set( or training set if `validation_split = 0` in the `TrainingGenerator`) at the end of each epoch and saves the evaluation data to a HDF5 log file( if `filepath` is set).
    nowstr = datetime.datetime.today().strftime('%Y%m%dT%H%M%S')
    logfile = 'log{}.h5'.format(nowstr)
    '''
    logger = deepposekit.callbacks.Logger(
                    filepath=os.path.join(outtouch,logfile),
                    validation_batch_size=10)
    '''

    # `ReduceLROnPlateau` automatically reduces the learning rate of the optimizer when the validation loss stops improving.This helps the model to reach a better optimum at the end of training.
    reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
        monitor="loss", # monitor="val_loss"
        factor=0.2,
        verbose=1,
        patience=20)

    train_generator = sdn.train_generator(
        n_outputs=sdn.n_outputs, batch_size=conf.batch_size, validation=False, confidence=True
    )
    #self.conf.dpk_n_outputs = n_outputs
    keypoint_generator = sdn.train_generator(
        n_outputs=1, batch_size=conf.batch_size, validation=True, confidence=False
    )
    aptcbk = deepposekit.callbacks.APTKerasCbk(conf, (train_generator, keypoint_generator))


    # `ModelCheckpoint` automatically saves the model when the validation loss improves at the end of each epoch. This allows you to automatically save the best performing model during training, without having to evaluate the performance manually.
    '''
    ckptfile = 'ckpt{}.h5'.format(nowstr)
    ckpt = os.path.join(outtouch, ckptfile)
    model_checkpoint = deepposekit.callbacks.ModelCheckpoint(
        ckpt,
        monitor="val_loss", # monitor="val_loss"
        verbose=1,
        save_best_only=True,
    )
    '''

    # `EarlyStopping` automatically stops the training session when the validation loss stops improving for a set number of epochs, which is set with the `patience` argument. This allows you to save time when training your model if there's not more improvment.
    '''
    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_loss", # monitor="val_loss"
        min_delta=0.001,
        patience=100,
        verbose=1
    )
    '''

    #callbacks = [early_stop, reduce_lr, model_checkpoint, logger]
    callbacks = [reduce_lr, aptcbk]

    return callbacks

def create_callbacks_orig(sdn, conf):
    logging.info("configing callbacks")

    # `Logger` evaluates the validation set( or training set if `validation_split = 0` in the `TrainingGenerator`) at the end of each epoch and saves the evaluation data to a HDF5 log file( if `filepath` is set).
    nowstr = datetime.datetime.today().strftime('%Y%m%dT%H%M%S')
    logfile = 'log{}.h5'.format(nowstr)
    logger = deepposekit.callbacks.Logger(
                    filepath=os.path.join(conf.cachedir, logfile),
                    validation_batch_size=10)

    # `ReduceLROnPlateau` automatically reduces the learning rate of the optimizer when the validation loss stops improving.This helps the model to reach a better optimum at the end of training.
    reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
        monitor="val_loss", # monitor="val_loss"
        factor=0.2,
        verbose=1,
        patience=20)

    train_generator = sdn.train_generator(
        n_outputs=sdn.n_outputs, batch_size=conf.batch_size, validation=False, confidence=True
    )
    #self.conf.dpk_n_outputs = n_outputs
    keypoint_generator = sdn.train_generator(
        n_outputs=1, batch_size=conf.batch_size, validation=True, confidence=False
    )
    aptcbk = deepposekit.callbacks.APTKerasCbk(conf, (train_generator, keypoint_generator))

    # `ModelCheckpoint` automatically saves the model when the validation loss improves at the end of each epoch. This allows you to automatically save the best performing model during training, without having to evaluate the performance manually.
    ckptfile = 'ckpt{}.h5'.format(nowstr)
    ckpt = os.path.join(conf.cachedir, ckptfile)
    model_checkpoint = deepposekit.callbacks.ModelCheckpoint(
        ckpt,
        monitor="val_loss",  # monitor="val_loss"
        verbose=1,
        save_best_only=True,
    )

    # `EarlyStopping` automatically stops the training session when the validation loss stops improving for a set number of epochs, which is set with the `patience` argument. This allows you to save time when training your model if there's not more improvment.
    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_loss",  # monitor="val_loss"
        min_delta=0.001,
        patience=100,
        verbose=1
    )

    callbacks = [early_stop, reduce_lr, model_checkpoint, logger]
    return callbacks
    #callbacks = [reduce_lr, aptcbk]

def predict_stuff(sdn, ims, locsgt, hmfloor=0.1, hmncluster=1):
    mt = sdn.train_model
    mp = sdn.predict_model

    sdnconf = sdn.get_config()
    npts = sdnconf['keypoints_shape'][0]
    unscalefac = 2**sdnconf['downsample_factor']

    yt = mt.predict(ims)
    yhm = op4.clip_heatmap_with_warn(yt[-1][..., :npts])
    locsTlo = hm.get_weighted_centroids(yhm, hmfloor, hmncluster)
    locsThi = opd.unscale_points(locsTlo, unscalefac)

    locsPhi = mp.predict(ims)
    locsPhi = locsPhi[..., :2]  # 3rd/last col is confidence

    errT = np.sqrt(np.sum((locsgt-locsThi)**2, axis=-1))
    errP = np.sqrt(np.sum((locsgt-locsPhi)**2, axis=-1))

    return errT, errP, locsThi, locsPhi

def apt_dpk_conf(data_generator, cacheroot, projname, expname, view=0):
    '''
    Truncated/simplified conf for dpk replication tests

    :param cachedir:
    :param data_generator:
    :return:
    '''
    conf = poseConfig.config()

    KEEPATTS = ['trainfilename', 'valfilename', 'dl_steps', 'display_step', 'save_step']
    attrs = vars(conf).keys()
    for att in attrs:
        if not att.startswith('dpk_') and att not in KEEPATTS:
            setattr(conf, att, ['__FOO_UNUSED__', ])

    conf.cachedir = os.path.join(cacheroot, projname, 'dpk',
                                 'view_{}'.format(view), expname)
    conf.n_classes = data_generator.n_keypoints
    conf.batch_size = 8
    imshape = data_generator.compute_image_shape()
    conf.imsz = imshape[:2]
    conf.img_dim = imshape[2]

    conf.dpk_graph = data_generator.graph
    conf.dpk_swap_index = data_generator.swap_index
    conf.dl_steps = 40000
    conf.save_step = 5000

    return conf

def apt_db_from_datagen(dg, split_file, dpkconf):
    '''
    Create APT-style train/val tfrecords from a DPK-style DataGenerator
    :param dg: DataGenerator instance
    :param split_file: json containing 'val_idx' field that lists 0b row indices for val split
    :param conf: APT conf (for specification of APT db locs)
    :return:
    '''

    with open(split_file) as fp:
        js = json.load(fp)
    val_idx = js['val_idx']
    nval = len(val_idx)
    n = len(dg)
    assert all((x < n for x in val_idx))
    print("Read json file {}. Found {} val_idx elements. Datagenerator has {} els.".format(
        split_file, nval, n))

    print("Datagenerator image/keypt shapes are {}, {}.".format(
        dg.compute_image_shape(), dg.compute_keypoints_shape() ) )

    env, val_env = multiResData.create_envs(dpkconf, True)

    count = 0
    val_count = 0
    for idx in range(n):
        im = dg.get_images([idx, ])
        loc = dg.get_keypoints([idx, ])
        info = [int(idx), int(idx), int(idx)]

        towrite = apt.tf_serialize([im[0, ...], loc[0, ...], info])
        if idx in val_idx:
            val_env.write(towrite)
            val_count += 1
        else:
            env.write(towrite)
            count += 1

        if idx % 100 == 99:
            print('%d,%d number of examples added to the training db and val db' % (count, val_count))

    print('%d,%d number of examples added to the training db and val db' % (count, val_count))

    split_file_dst = os.path.join(dpkconf.cachedir,
                                  dpkconf.valfilename+"."+os.path.basename(split_file))
    shutil.copyfile(split_file, split_file_dst)
    print('Copied split file {} -> {}'.format(split_file, split_file_dst))

def make_augmenter(data_generator):
    augmenter = []

    augmenter.append(FlipAxis(data_generator, axis=0))  # flip image up-down
    augmenter.append(FlipAxis(data_generator, axis=1))  # flip image left-right

    sometimes = []
    sometimes.append(iaa.Affine(scale={"x": (0.95, 1.05), "y": (0.95, 1.05)},
                                translate_percent={'x': (-0.05, 0.05), 'y': (-0.05, 0.05)},
                                shear=(-8, 8),
                                order=ia.ALL,
                                cval=ia.ALL,
                                mode=ia.ALL)
                     )
    sometimes.append(iaa.Affine(scale=(0.9, 1.1),
                                mode=ia.ALL,
                                order=ia.ALL,
                                cval=ia.ALL)
                     )
    augmenter.append(iaa.Sometimes(0.75, sometimes))
    augmenter.append(iaa.Affine(rotate=(-180, 180),
                                mode=ia.ALL,
                                order=ia.ALL,
                                cval=ia.ALL)
                     )
    augmenter = iaa.Sequential(augmenter)

    # Noise

    # Dropout

    # Blur/sharpen

    # Contrast

    return augmenter

def train(cdpk, augmenter, compileonly=False):

    roundupeven = lambda x: x + x % 2
    imsznet = cdpk.imsz
    imsznet = (roundupeven(imsznet[0]), roundupeven(imsznet[1]))
    cdpk.dpk_imsz_net = imsznet
    cdpk.dpk_im_padx = cdpk.dpk_imsz_net[1] - cdpk.imsz[1]
    cdpk.dpk_im_pady = cdpk.dpk_imsz_net[0] - cdpk.imsz[0]
    cdpk.dpk_augmenter = augmenter
    cdpk.dpk_use_augmenter = True

    tgtfr = TGTFR.TrainingGeneratorTFRecord(cdpk)
    sdn = StackedDenseNet(tgtfr,
                          n_stacks=cdpk.dpk_n_stacks,
                          growth_rate=cdpk.dpk_growth_rate,
                          pretrained=cdpk.dpk_use_pretrained)
    cbk = create_callbacks(sdn, cdpk)

    optimizer = tf.keras.optimizers.Adam(
        lr=.001, beta_1=0.9, beta_2=0.999, epsilon=None, decay=0.0, amsgrad=False)
    sdn.compile(optimizer=optimizer, loss='mse')

    if compileonly:
        return sdn, cbk
    else:
        tgconf = tgtfr.get_config()
        sdnconf = sdn.get_config()
        conf_file = os.path.join(cdpk.cachedir, 'conf.pickle')
        with open(conf_file, 'wb') as fh:
            pickle.dump({'cdpk': cdpk, 'tg': tgconf, 'sdn': sdnconf}, fh)
        logging.info("Saved confs to {}".format(conf_file))

        sdn.fit(
            batch_size=cdpk.batch_size,
            validation_batch_size=cdpk.batch_size,
            callbacks=cbk,
            epochs=cdpk.dl_steps//cdpk.display_step,
            steps_per_epoch=cdpk.display_step, )  # validation_steps=50, validation_freq=10)

def train_orig(cdpk, dg, augmenter):
    train_generator = deepposekit.io.TrainingGenerator(
                        generator=dg,
                        downsample_factor=cdpk.dpk_downsample_factor,
                        augmenter=augmenter,
                        sigma=5,
                        validation_split=0.1,
                        use_graph=True,
                        random_seed=1,
                        graph_scale=1)
    sdn = StackedDenseNet(train_generator,
                          n_stacks=cdpk.dpk_n_stacks,
                          growth_rate=cdpk.dpk_growth_rate,
                          pretrained=cdpk.dpk_use_pretrained)
    cbk = create_callbacks_orig(sdn, cdpk)

    optimizer = tf.keras.optimizers.Adam(
        lr=.001, beta_1=0.9, beta_2=0.999, epsilon=None, decay=0.0, amsgrad=False)
    sdn.compile(optimizer=optimizer, loss='mse')

    tgconf = train_generator.get_config()
    sdnconf = sdn.get_config()
    conf_file = os.path.join(cdpk.cachedir, 'conf.pickle')
    with open(conf_file, 'wb') as fh:
        pickle.dump({'cdpk': cdpk, 'tg': tgconf, 'sdn': sdnconf}, fh)
    logging.info("Saved confs to {}".format(conf_file))

    sdn.fit(
        batch_size=cdpk.batch_size,
        validation_batch_size=cdpk.batch_size,
        callbacks=cbk,
        epochs=cdpk.dpk_origtrain_nsteps,
        steps_per_epoch=None)



def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('--expname',
                        required=True,
                        help='Experiment name')
    parser.add_argument('--origtrain',
                        action='store_true',
                        help='Specify to use original TrainingGenerator/train codepath')
    parser.add_argument('--dpkdset',
                        choices=['fly'],
                        help='DPK dataset name',
                        default='fly')
    parser.add_argument('--cacheroot',
                        default=cacheroot)
    args = parser.parse_args(argv)

    if args.dpkdset == 'fly':
        h5file = dpk_fly_h5
        dpk_origtrain_nsteps = 400
    else:
        assert False

    projname = 'dpk' + args.dpkdset

    dg = deepposekit.io.DataGenerator(h5file)
    augmenter = make_augmenter(dg)
    cdpk = apt_dpk_conf(dg, args.cacheroot, projname, args.expname)

    if args.origtrain:
        setattr(cdpk, 'dpk_origtrain_nsteps', dpk_origtrain_nsteps)
        train_orig(cdpk, dg, augmenter)
    else:
        train(cdpk, augmenter)

if __name__ == "__main__" and len(sys.argv) > 1:
    main(sys.argv[1:])
else:
    h5file = dpk_fly_h5
    dg = deepposekit.io.DataGenerator(h5file)
    cdpk = apt_dpk_conf(dg, cacheroot, 'testproj', 'testexp')
    augmenter = make_augmenter(dg)
    sdn, cbks = train(cdpk, augmenter, compileonly=True)

    '''
    import cv2

    im = cv2.imread(isotri)
    loc = isotrilocs
    im = im[np.newaxis, ...]
    loc = loc[np.newaxis, ...]
    (im_lr, locs_lr), (im_ud, locs_ud), (im_lria, locs_lria), (im_udia, locs_udia) = check_flips(im,loc,isotriswapidx)

    PoseTools.show_result(im, range(1), loc, fignum=10, mrkrsz=200)
    PoseTools.show_result(im_udia, range(1), locs_udia, fignum=11, mrkrsz=200)
    PoseTools.show_result(im_lria, range(1), locs_lria, fignum=12, mrkrsz=200)
    '''

'''
if False:
    skel = '/groups/branson/home/leea30/apt/dpk20191114/skeleton.csv'
    s = ut.initialize_skeleton(skel)
    skeleton = s[["tree", "swap_index"]].values
    c.dpk_graph = skeleton[:, 0]
    c.dpk_swap_index = skeleton[:, 1]
'''
