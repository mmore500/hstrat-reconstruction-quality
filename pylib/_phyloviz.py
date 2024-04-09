import typing

import alifedata_phyloinformatics_convert as apc
from Bio import Phylo
from colorclade._biopython_sort_tree import biopython_sort_tree
from hstrat import hstrat
from hstrat import _auxiliary_lib as hstrat_aux
from hsurf import hsurf
from matplotlib import pyplot as plt
import numpy as np
import pandas as pd
import tqdist
from tqdm.notebook import tqdm


def logify_phylo(phylo_df):
    phylo_df = phylo_df.copy()
    phylo_df["log time ago"] = np.log(
        phylo_df["origin_time"].max() - phylo_df["origin_time"] + 1
    )
    phylo_df["origin_time"] = (
        phylo_df["log time ago"].max() - phylo_df["log time ago"]
    )
    return phylo_df


def make_policy(
    stratum_retention_algo,
    annotation_size_bits,
    differentia_width_bits,
    num_generations,
):
    stratum_retention_algo = {
        "col-steady": hstrat.depth_proportional_resolution_tapered_algo,
        "surf-hybrid": hsurf.stratum_retention_interop_hybrid_algo,
        "surf-tilted": hsurf.stratum_retention_interop_tilted_sticky_algo,
    }[stratum_retention_algo]

    annotation_capacity_strata = annotation_size_bits // differentia_width_bits
    assert (
        annotation_capacity_strata.bit_count() == 1
    ), "must be power of 2 (1, 2, 4, 8, etc.)"
    print(f"{annotation_capacity_strata=}")

    parametrized_policy = stratum_retention_algo.Policy(
        parameterizer=hstrat.PropertyAtMostParameterizer(
            target_value=annotation_capacity_strata,
            policy_evaluator=hstrat.NumStrataRetainedUpperBoundEvaluator(
                at_num_strata_deposited=num_generations,
            ),
            param_lower_bound=2,
            param_upper_bound=1024,
        ),
    )

    return parametrized_policy


def make_reconstructed_rosettatree(
    stratum_retention_algo,
    annotation_size_bits,
    differentia_width_bits,
    true_phylogeny_df,
    num_generations,
):
    parametrized_policy = make_policy(
        stratum_retention_algo,
        annotation_size_bits,
        differentia_width_bits,
        num_generations,
    )
    extant_annotations = hstrat.descend_template_phylogeny_alifestd(
        true_phylogeny_df,
        seed_column=hstrat.HereditaryStratigraphicColumn(
            parametrized_policy,
            stratum_differentia_bit_width=differentia_width_bits,
        ),
        extant_ids=hstrat_aux.alifestd_find_leaf_ids(true_phylogeny_df),
        progress_wrap=tqdm,
    )

    reconstructed_phylogeny_df = hstrat.build_tree_trie(
        extant_annotations,
        bias_adjustment=hstrat.CompoundTriePostprocessor(
            [
                hstrat.PeelBackConjoinedLeavesTriePostprocessor(),
                hstrat.AssignOriginTimeSampleNaiveTriePostprocessor(),
            ],
        ),
        progress_wrap=tqdm,
        taxon_labels=true_phylogeny_df.loc[
            hstrat_aux.alifestd_find_leaf_ids(true_phylogeny_df),
            "taxon_label",
        ],
    )

    return apc.RosettaTree(
        logify_phylo(reconstructed_phylogeny_df),
    )


def prune_100(tree, seed):
    df = tree.as_alife.copy()
    leaf_ids = hstrat_aux.alifestd_find_leaf_ids(df)
    leaf_taxa = df.loc[leaf_ids, "taxon_label"].tolist()
    downsample_taxa = np.random.default_rng(seed).choice(
        sorted(leaf_taxa, key=str),
        100,
        replace=False,
    )
    df["extant"] = False
    df.loc[
        df["taxon_label"].isin(downsample_taxa),
        "extant",
    ] = True
    df = hstrat_aux.alifestd_prune_extinct_lineages_asexual(
        df,
        mutate=True,
    )
    return apc.RosettaTree(df)


def plot2(tree_a, tree_b, seed, ax=None):
    if ax is None:
        fig, ax = plt.subplots()

    bp = prune_100(tree_a, seed).as_biopython
    biopython_sort_tree(bp.root)
    for clade in bp.find_clades():
        clade.color = "orange"
    with plt.rc_context({"lines.linewidth": 2.2}):
        Phylo.draw(
            bp,
            do_show=False,
            axes=ax,
            label_func=lambda x: None,
            branch_labels=None,
        )

    bp = prune_100(tree_b, seed).as_biopython
    biopython_sort_tree(bp.root)
    for clade in bp.find_clades():
        clade.color = "blue"

    with plt.rc_context({"lines.linewidth": 0.75}):
        Phylo.draw(
            bp,
            do_show=False,
            axes=ax,
            label_func=lambda x: None,
            branch_labels=None,
        )

    # Remove axes borders except for bottom, and remove y-axis tick/labels
    ax.spines["top"].set_visible(False)
    ax.spines["bottom"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_visible(False)
    ax.set_xticklabels([])
    ax.set_xticks([])
    ax.set_yticklabels([])
    ax.set_yticks([])
    ax.axes.get_xaxis().set_visible(False)
    ax.axes.get_yaxis().set_visible(False)

    return ax


def calc_tqdist_distance(
    x: pd.DataFrame,
    y: pd.DataFrame,
    progress_wrap: typing.Callable = lambda x: x,
) -> float:
    """Calculate dissimilarity between two trees. Used to measure how accurate
    tree reconstructions are."""
    tree_a = apc.RosettaTree(x, validate="error").as_dendropy
    tree_b = apc.RosettaTree(y, validate="error").as_dendropy

    # must suppress root unifurcations or tqdist barfs
    # see https://github.com/uym2/tripVote/issues/15
    tree_a.unassign_taxa(exclude_leaves=True)
    tree_a.suppress_unifurcations()
    tree_b.unassign_taxa(exclude_leaves=True)
    tree_b.suppress_unifurcations()

    tree_a_taxon_labels = [
        leaf.taxon.label for leaf in progress_wrap(tree_a.leaf_node_iter())
    ]
    tree_b_taxon_labels = [
        leaf.taxon.label for leaf in progress_wrap(tree_b.leaf_node_iter())
    ]
    all(
        progress_wrap(
            zip(tree_a.leaf_node_iter(), tree_b.leaf_node_iter(), strict=True),
        ),
    )
    assert sorted(tree_a_taxon_labels) == sorted(tree_b_taxon_labels)
    assert sorted(tree_a_taxon_labels) == sorted(
        x.loc[hstrat_aux.alifestd_find_leaf_ids(x), "taxon_label"],
    )
    assert sorted(tree_a_taxon_labels) == sorted(
        y.loc[hstrat_aux.alifestd_find_leaf_ids(y), "taxon_label"],
    )
    for taxon_label in progress_wrap(tree_a_taxon_labels):
        assert taxon_label
        assert taxon_label.strip()

    newick_a = tree_a.as_string(schema="newick").strip()
    newick_b = tree_b.as_string(schema="newick").strip()

    return {
        "quartet_distance": tqdist.quartet_distance(newick_a, newick_b),
        "quartet_distanc_raw": tqdist.quartet_distance_raw(newick_a, newick_b),
        "triplet_distance": tqdist.triplet_distance(newick_a, newick_b),
        "triplet_distance_raw": tqdist.triplet_distance_raw(newick_a, newick_b),
    }
