import subprocess
import tempfile

from pandas.io.formats.style import Styler as pd_Styler
from weasyprint import HTML as weasy_HTML


def styler_to_pdf(
    styler: pd_Styler, filename: str, quiet: bool = False
) -> None:
    """Convert a Styler object to a PDF file and post-process with Inkscape.

    This function first converts a Pandas Styler object into a PDF file using WeasyPrint.
    It then uses Inkscape to post-process the PDF file, such as fitting the page to the selection.

    Parameters
    ----------
    styler : pd_Styler
        The Styler object to convert to a PDF file.
    filename : str
        The name of the PDF file to create.
    """

    stderr = subprocess.STDOUT if not quiet else subprocess.DEVNULL
    stdout = subprocess.PIPE if not quiet else subprocess.DEVNULL

    html = weasy_HTML(string=styler.to_html())
    with tempfile.NamedTemporaryFile(delete=True, suffix=".pdf") as temp_file:
        html.write_pdf(temp_file.name)
        result = subprocess.run(
            [
                "inkscape",
                temp_file.name,
                "--actions=page-fit-to-selection",
                "-o",
                filename,
            ],
            check=True,
            stderr=stderr,
            stdout=stdout,
        )

    # Log the output if not quiet
    if not quiet:
        print("inkscape output:\n", result.stdout.decode())
