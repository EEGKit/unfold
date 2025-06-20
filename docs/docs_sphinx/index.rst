|
|
.. unfold documentation master file
.. highlight:: matlab

.. container:: landing

  .. container:: center-div

    .. image:: ../../media/unfold_800x377.png
      :align: center
      :width: 30 %

Unfold.jl - in Julia
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
We are actively continuing Unfold in Julia (under the name Unfold.jl <https://github.com/unfoldtoolbox/UnfoldDocs/>). It has several new features like event-specific timewindows, MixedModels, GPU-fitting etc. It further has a more extensive ecosystem consisting of a Plotting, a Simulation, a Decoding, a BIDS and a Statistics toolbox.


Unfold 1.2 - EEG Deconvolution Toolbox
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
A toolbox for *deconvolution* of overlapping EEG (Pupil, LFP etc.) signals and *(non)-linear modeling*

New in 1.2 (December 2020): More automatic cleaning tools (ASR, Entropy-Based). Many Bugfixes, better Documentation and better error-codes.
Januar 2025: MatLab Unfold is still actively maintained, but no new features are currently added. PRs are welcome!

Reference Papers
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
`Download our reference paper Ehinger & Dimigen 2019 <https://peerj.com/articles/7838/>`_ (peerJ).

We recently published a new preprint on the analysis of Eyetracking/EEG data, with *unfold* playing a prominent role `Dimigen & Ehinger 2019 <https://www.biorxiv.org/content/10.1101/735530v1>`_


If you use the toolbox, please cite us as: Ehinger BV & Dimigen O, *Unfold: An integrated toolbox for overlap correction, non-linear modeling, and regression-based EEG analysis*, peerJ, https://peerj.com/articles/7838/

Why deconvolution and non-linear modeling?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Find a `twitter thread explaining the general idea here <https://twitter.com/BenediktEhinger/status/1036553493191032832>`_
or have a look at Figure 1 of `our paper <https://peerj.com/articles/7838/>`_

What can you do with *unfold*?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* Adjust for **overlap** between subsequent potentials using linear deconvolution
* Massive-Univarite Modeling (rERP) using R-style formulas, e.g. ``EEG~1+face+age``
* Non-linear effects using **regression splines** (GAM), e.g. ``EEG~1+face+spl(age,10)``
* Model **multiple events**, e.g. *Stimulus*, *Response* and *Fixation*
* Use temporal basis functions (Fourier & Splines)
* (Optional) **regularization** using glmnet
* Temporal Response Functions (TRFs)


Requirements
^^^^^^^^^^^^^^^^^
* MATLAB 2015a+
* Statistics Toolbox
* Continuous data in EEGLAB 12+ format
* Unfold toolbox `Download it on GitHub <https://github.com/unfoldtoolbox/unfold/>`_

Getting Started
^^^^^^^^^^^^^^^^^
To get started, best is to start with the 2x2 ANOVA-Design tutorial :doc:`toolbox-tut01`


.. raw:: html
    <iframe style="border: 0; height: 200px; width: 600px;"       src="https://www.unfoldtoolbox.org/piwik/index.php?module=CoreAdminHome&action=optOut&language=en&backgroundColor=&fontColor=&fontSize=&fontFamily"></iframe>



.. toctree::
   :maxdepth: 4
   :hidden:

   overview
   contenttutorials
   toolboxtutorials
   documentation
   datastructures
   
