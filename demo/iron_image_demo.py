# iron inline image test — send one cell at a time (cells are split by "# %%").
#
# REPL: python or ipython with `image = true` in the repl definition.
# plotly needs plotly + kaleido (+ Chrome) in the REPL's env: ~/.sysvenv/venv
# has them; ~/.venvman/envs/3.13/dev does not (skip the plotly cells there).
#
# Each cell says what you should see. ":IronImageOpen" works with the cursor
# on an image in the REPL buffer, or from this buffer for the latest image.

# %% 0. Setup: nothing iron-related should be in your namespace
print([name for name in dir() if "iron" in name.lower()])  # expect: []

# %% 1. matplotlib: plt.show() draws inline
import matplotlib.pyplot as plt

print(plt.get_backend())  # expect: module://iron_image.integrations.matplotlib
fig = plt.figure()
plt.plot([1, 3, 2, 5, 4])
plt.title("matplotlib: line")
plt.show()
# expect: one inline plot

# %% 2. matplotlib: :IronImageOpen opens an interactive window
# Run :IronImageOpen now (cursor on the plot above, or from here).
# expect: a Qt window with zoom/pan toolbar; closing it is fine

# %% 3. matplotlib: two figures, one show()
plt.figure()
plt.bar(["a", "b", "c"], [3, 1, 2])
plt.title("matplotlib: bars")
plt.figure()
plt.scatter([1, 2, 3, 4], [4, 1, 3, 2])
plt.title("matplotlib: scatter")
plt.show()
# expect: two inline plots

# %% 4. matplotlib: a wide figure keeps its shape
plt.figure(figsize=(12, 2))
plt.plot(range(50))
plt.title("matplotlib: wide")
plt.show()
# expect: one inline plot, wide and short (not stretched)

# %% 5. Pillow: img.show() draws inline instead of an external viewer
from PIL import Image, ImageDraw

img = Image.new("RGB", (300, 150), "white")
draw = ImageDraw.Draw(img)
draw.rectangle([20, 20, 140, 130], fill="red")
draw.ellipse([160, 20, 280, 130], fill="blue")
img.show()
# expect: one inline image (red square, blue circle); no external viewer

# %% 6. Pillow: a mode PNG can't store (CMYK) is converted
Image.new("CMYK", (200, 100), (0, 255, 255, 0)).show()
# expect: one inline red-ish image

# %% 7. Pillow, ipython only: display(img) and a bare img
display(img)  # noqa: F821  # pyright: ignore[reportUndefinedVariable]
# expect (ipython): inline image.  plain python: NameError, skip this cell

# %% 8. Pillow, ipython only: bare image on the last line
img  # pyright: ignore[reportUnusedExpression]
# expect (ipython): Out[n]: followed by the inline image
# expect (python): text like <PIL.Image.Image image mode=RGB size=300x150 ...>

# %% 9. plotly: fig.show() draws inline (first one ~1.5 s, later ~0.1 s)
import plotly.graph_objects as go

pfig = go.Figure(
    go.Scatter(y=[1, 3, 2, 5, 4], mode="lines+markers"),
    layout={"title": "plotly: line"},
)
pfig.show()
# expect: one inline plot

# %% 10. plotly: :IronImageOpen opens the interactive chart in your browser
# Run :IronImageOpen now (cursor on the plotly image, or from here).
# expect: the chart opens in your default browser, hover/zoom works, and it
# works offline

# %% 11. plotly: a second figure is fast
go.Figure(go.Bar(x=["a", "b", "c"], y=[3, 1, 2])).show()
# expect: one inline bar chart, noticeably faster than cell 9

# %% 12. plotly, ipython only: bare figure on the last line
go.Figure(go.Pie(labels=["x", "y", "z"], values=[3, 2, 1]))
# expect (ipython): inline pie chart.  plain python: text repr

# %% 13. Not supported (by design, for reference)
display(fig)  # noqa: F821  # pyright: ignore[reportUndefinedVariable]
# expect (ipython): text "<Figure size ... with 1 Axes>" — matplotlib figures
# only show through plt.show() (display(fig) is an open decision)
